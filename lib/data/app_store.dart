/// The device-side store (#83): small versioned JSON documents in the app's
/// private files directory, written atomically, read back tolerantly, never
/// sent anywhere.
///
/// Every document is `{"format": 1, "data": {...}}`. A document that is
/// missing loads as absent; one that is damaged is moved aside as
/// `<name>.bad-<epochMillis>.json`, loads as absent, and raises a notice the
/// menu shows once (`meta` excepted). Persistence never blocks play: a write
/// that fails is logged in debug builds and otherwise swallowed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/platform_channel.dart';

/// The five documents the app keeps.
enum StoreDoc {
  settings('settings'),
  stats('stats'),
  gameKlondike('game-klondike'),
  gameSpider('game-spider'),
  meta('meta');

  const StoreDoc(this.fileName);

  final String fileName;

  /// `meta` only holds `lastPlayed`; its loss is not worth a banner.
  bool get raisesNotice => this != meta;
}

/// The envelope version this build reads and writes.
const int storeFormat = 1;

/// How many quarantined copies of one document are kept.
const int quarantineKeep = 3;

sealed class StoreResult {
  const StoreResult();
}

class Loaded extends StoreResult {
  const Loaded(this.data);

  final Map<String, Object?> data;
}

class Absent extends StoreResult {
  const Absent();
}

class AppStore {
  /// Production: the directory comes from the platform channel; on any
  /// failure the store falls back to memory (persistence off, nothing
  /// crashes).
  AppStore.platform(PlatformChannel channel)
    : _resolveDir = (() => _platformDir(channel));

  /// Tests: a temp directory in place of the channel.
  AppStore.directory(Directory directory)
    : _resolveDir = (() async => directory);

  /// An in-memory store behind the same API.
  AppStore.memory() : _resolveDir = (() async => null);

  static Future<Directory?> _platformDir(PlatformChannel channel) async {
    try {
      final path = await channel.filesDir();
      if (path == null) return null;
      return Directory(path);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  final Future<Directory?> Function() _resolveDir;
  Future<_Backend>? _backend;

  /// Documents whose file was damaged and moved aside, until the menu's
  /// banner is dismissed (#94).
  final ValueNotifier<Set<StoreDoc>> corruptionNotices = ValueNotifier(
    const {},
  );

  /// The latest value queued for each document, and the write in flight.
  final Map<StoreDoc, Map<String, Object?>> _queued = {};
  final Map<StoreDoc, Future<void>> _inFlight = {};
  final Map<StoreDoc, Completer<void>> _landed = {};

  /// The backend, resolved once. A directory that cannot be created falls
  /// back to memory.
  Future<_Backend> get _store => _backend ??= _open();

  Future<_Backend> _open() async {
    Directory? dir;
    try {
      dir = await _resolveDir();
    } on Object catch (e) {
      debugPrint('app store: directory unavailable ($e); persistence is off');
      dir = null;
    }
    if (dir == null) return _MemoryBackend();
    try {
      final data = Directory('${dir.path}/data');
      await data.create(recursive: true);
      final backend = _FileBackend(data);
      await backend.sweepStaleTemps();
      return backend;
    } on FileSystemException catch (e) {
      debugPrint('app store: cannot use ${dir.path} ($e); persistence is off');
      return _MemoryBackend();
    }
  }

  /// Whether this store keeps its documents on disk (false in memory).
  Future<bool> get persistent async => (await _store) is _FileBackend;

  /// The document's `data`, or absent. A pending write's value is returned
  /// without touching the disk.
  Future<StoreResult> read(StoreDoc doc) async {
    final queued = _queued[doc];
    if (queued != null) return Loaded(Map<String, Object?>.of(queued));
    final backend = await _store;
    final String? text;
    try {
      text = await backend.readString(doc.fileName);
    } on FileSystemException catch (e) {
      // An I/O failure, not damaged content: leave the file, no notice.
      debugPrint('app store: cannot read ${doc.fileName} ($e)');
      return const Absent();
    }
    if (text == null) return const Absent();
    final data = _unwrap(text);
    if (data == null) {
      await _quarantine(backend, doc, 'damaged content');
      return const Absent();
    }
    return Loaded(data);
  }

  /// The `data` of a valid envelope, or null when the text is not one.
  static Map<String, Object?>? _unwrap(String text) {
    if (text.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final format = decoded['format'];
    if (format is! int || format != storeFormat) return null;
    final data = decoded['data'];
    if (data is! Map) return null;
    return data.cast<String, Object?>();
  }

  /// Queues [data] for [doc]; completes when these bytes (or a later
  /// write's) are renamed into place. A value `jsonEncode` rejects throws.
  Future<void> write(StoreDoc doc, Map<String, Object?> data) {
    final text = jsonEncode({
      'format': storeFormat,
      'data': data,
    }); // throws for bad values
    _queued[doc] = data;
    final landed = _landed[doc] ??= Completer<void>();
    _inFlight[doc] ??= _drain(doc);
    // Cache the encoded text with the queue so the drain writes exactly this.
    _encoded[doc] = text;
    return landed.future;
  }

  final Map<StoreDoc, String> _encoded = {};

  Future<void> _drain(StoreDoc doc) async {
    final backend = await _store;
    while (_queued.containsKey(doc)) {
      final text = _encoded.remove(doc)!;
      _queued.remove(doc);
      final landed = _landed.remove(doc);
      try {
        await backend.writeAtomic(doc.fileName, text);
      } on FileSystemException catch (e) {
        debugPrint('app store: write of ${doc.fileName} failed ($e)');
      }
      landed?.complete();
    }
    _inFlight.remove(doc);
  }

  /// Removes the document; queued writes for it are dropped first. Missing
  /// is a silent no-op.
  Future<void> delete(StoreDoc doc) async {
    _queued.remove(doc);
    _encoded.remove(doc);
    _landed.remove(doc)?.complete();
    final pending = _inFlight[doc];
    if (pending != null) await pending;
    final backend = await _store;
    try {
      await backend.delete(doc.fileName);
    } on FileSystemException catch (e) {
      debugPrint('app store: delete of ${doc.fileName} failed ($e)');
    }
  }

  /// Moves the document aside as damaged (a semantic failure such as a save
  /// that no longer replays) and raises its notice.
  Future<void> quarantine(StoreDoc doc, String reason) async {
    _queued.remove(doc);
    _encoded.remove(doc);
    _landed.remove(doc)?.complete();
    final pending = _inFlight[doc];
    if (pending != null) await pending;
    await _quarantine(await _store, doc, reason);
  }

  Future<void> _quarantine(
    _Backend backend,
    StoreDoc doc,
    String reason,
  ) async {
    debugPrint('app store: quarantining ${doc.fileName}: $reason');
    try {
      await backend.quarantine(doc.fileName);
    } on FileSystemException catch (e) {
      debugPrint('app store: quarantine of ${doc.fileName} failed ($e)');
    }
    if (doc.raisesNotice) {
      corruptionNotices.value = {...corruptionNotices.value, doc};
    }
  }

  /// Clears the banner's notices (the menu's dismiss button).
  void dismissNotices() => corruptionNotices.value = const {};

  /// Waits for every queued write to land (background flushes, dispose).
  Future<void> flush() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.values.toList());
    }
  }
}

abstract class _Backend {
  Future<String?> readString(String name);
  Future<void> writeAtomic(String name, String text);
  Future<void> delete(String name);
  Future<void> quarantine(String name);
}

class _MemoryBackend implements _Backend {
  final Map<String, String> _files = {};

  @override
  Future<String?> readString(String name) async => _files[name];

  @override
  Future<void> writeAtomic(String name, String text) async =>
      _files[name] = text;

  @override
  Future<void> delete(String name) async => _files.remove(name);

  @override
  Future<void> quarantine(String name) async => _files.remove(name);
}

/// `<dir>/<name>.json`, written through `<name>.json.tmp` then renamed.
class _FileBackend implements _Backend {
  _FileBackend(this.dir);

  final Directory dir;

  File _file(String name) => File('${dir.path}/$name.json');
  File _temp(String name) => File('${dir.path}/$name.json.tmp');

  /// A `.tmp` left by an interrupted write is never recovered.
  Future<void> sweepStaleTemps() async {
    for (final doc in StoreDoc.values) {
      final temp = _temp(doc.fileName);
      if (await temp.exists()) await temp.delete();
    }
  }

  @override
  Future<String?> readString(String name) async {
    final file = _file(name);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return '\u0000invalid utf-8'; // damaged content, not I/O: the caller quarantines
    }
  }

  @override
  Future<void> writeAtomic(String name, String text) async {
    final temp = _temp(name);
    await temp.writeAsString(text, flush: true);
    await temp.rename(_file(name).path);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> quarantine(String name) async {
    final file = _file(name);
    if (!await file.exists()) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var target = File('${dir.path}/$name.bad-$stamp.json');
    var n = 1;
    while (await target.exists()) {
      target = File('${dir.path}/$name.bad-$stamp-${n++}.json');
    }
    try {
      await file.rename(target.path);
    } on FileSystemException {
      await file.delete(); // the notice must never repeat
      return;
    }
    await _prune(name);
  }

  /// Keeps the three newest quarantined copies by the stamp in the name.
  Future<void> _prune(String name) async {
    final prefix = '$name.bad-';
    final bad = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final base = entity.uri.pathSegments.last;
        if (base.startsWith(prefix) && base.endsWith('.json')) bad.add(entity);
      }
    }
    int stampOf(File f) {
      final base = f.uri.pathSegments.last;
      final rest = base.substring(prefix.length, base.length - '.json'.length);
      final parts = rest.split('-');
      return int.tryParse(parts.first) ?? 0;
    }

    bad.sort((a, b) => stampOf(b).compareTo(stampOf(a)));
    for (final old in bad.skip(quarantineKeep)) {
      await old.delete();
    }
  }
}
