import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';

void main() {
  late Directory temp;
  late AppStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('hs-store-');
    store = AppStore.directory(temp);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  File fileOf(StoreDoc doc) => File('${temp.path}/data/${doc.fileName}.json');

  Future<List<String>> names() async => [
    await for (final e in Directory('${temp.path}/data').list())
      e.uri.pathSegments.last,
  ]..sort();

  test('every document round-trips through its envelope', () async {
    for (final doc in StoreDoc.values) {
      final data = {
        'doc': doc.name,
        'n': 1,
        'list': [1, 2],
      };
      await store.write(doc, data);
      expect(
        await store.read(doc),
        isA<Loaded>().having((l) => l.data, 'data', data),
      );
      final text = await fileOf(doc).readAsString();
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['format'], 1);
      expect(json['data'], data);
    }
    expect(await store.persistent, isTrue);
  });

  test('a missing document is absent; a fresh store over the same directory reads what was written', () async {
    expect(await store.read(StoreDoc.stats), isA<Absent>());
    await store.write(StoreDoc.stats, {'played': 3});
    final again = AppStore.directory(temp);
    expect((await again.read(StoreDoc.stats) as Loaded).data, {'played': 3});
  });

  test('writes are atomic: a leftover .tmp never replaces the old file, and is swept', () async {
    await store.write(StoreDoc.settings, {'v': 1});
    // An interrupted write: the temp file exists, the rename never happened.
    final tmp = File('${temp.path}/data/settings.json.tmp');
    await tmp.writeAsString('{"format":1,"data":{"v":2}}');
    final fresh = AppStore.directory(temp);
    expect((await fresh.read(StoreDoc.settings) as Loaded).data, {'v': 1});
    expect(await tmp.exists(), isFalse, reason: 'swept at startup');
    expect(await names(), isNot(contains('settings.json.tmp')));
  });

  test(
    'the last queued write wins and read returns it before it lands',
    () async {
      final writes = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        writes.add(store.write(StoreDoc.stats, {'i': i}));
      }
      expect((await store.read(StoreDoc.stats) as Loaded).data, {'i': 19});
      await Future.wait(writes);
      expect(jsonDecode(await fileOf(StoreDoc.stats).readAsString()), {
        'format': 1,
        'data': {'i': 19},
      });
    },
  );

  group('damaged documents are quarantined once, load as absent, and raise a notice', () {
    for (final (label, contents) in [
      ('garbage', 'not json at all'),
      ('an empty file', ''),
      ('whitespace', '  \n'),
      ('no format', '{"data":{}}'),
      ('format 2', '{"format":2,"data":{}}'),
      ('format as a string', '{"format":"1","data":{}}'),
      ('no data object', '{"format":1}'),
      ('data not an object', '{"format":1,"data":[1]}'),
      ('a list', '[1,2,3]'),
    ]) {
      test(label, () async {
        await Directory('${temp.path}/data').create(recursive: true);
        await fileOf(StoreDoc.stats).writeAsString(contents);
        expect(await store.read(StoreDoc.stats), isA<Absent>());
        expect(store.corruptionNotices.value, {StoreDoc.stats});
        final files = await names();
        expect(
          files.where((n) => n.startsWith('stats.bad-') && n.endsWith('.json')),
          hasLength(1),
          reason: '$files',
        );
        expect(files, isNot(contains('stats.json')));
        // A second read is plainly absent: no second notice, no second copy.
        expect(await store.read(StoreDoc.stats), isA<Absent>());
        expect(store.corruptionNotices.value, {StoreDoc.stats});
        expect(
          (await names()).where((n) => n.startsWith('stats.bad-')),
          hasLength(1),
        );
      });
    }

    test('invalid UTF-8 counts as damaged content', () async {
      await Directory('${temp.path}/data').create(recursive: true);
      await fileOf(StoreDoc.settings).writeAsBytes([0xFF, 0xFE, 0x7B]);
      expect(await store.read(StoreDoc.settings), isA<Absent>());
      expect(store.corruptionNotices.value, {StoreDoc.settings});
    });

    test('meta raises no notice', () async {
      await Directory('${temp.path}/data').create(recursive: true);
      await fileOf(StoreDoc.meta).writeAsString('nope');
      expect(await store.read(StoreDoc.meta), isA<Absent>());
      expect(store.corruptionNotices.value, isEmpty);
    });

    test('notices combine and dismiss', () async {
      await Directory('${temp.path}/data').create(recursive: true);
      await fileOf(StoreDoc.stats).writeAsString('x');
      await fileOf(StoreDoc.gameKlondike).writeAsString('y');
      await store.read(StoreDoc.stats);
      await store.read(StoreDoc.gameKlondike);
      expect(store.corruptionNotices.value, {
        StoreDoc.stats,
        StoreDoc.gameKlondike,
      });
      store.dismissNotices();
      expect(store.corruptionNotices.value, isEmpty);
    });

    test('quarantined copies are capped at three per document', () async {
      for (var i = 0; i < 5; i++) {
        await store.write(StoreDoc.stats, {'i': i});
        await store.quarantine(StoreDoc.stats, 'test $i');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final bad = (await names())
          .where((n) => n.startsWith('stats.bad-'))
          .toList();
      expect(bad, hasLength(3), reason: '$bad');
      expect(await store.read(StoreDoc.stats), isA<Absent>());
    });
  });

  test(
    'delete removes the file and drops queued writes; missing is a no-op',
    () async {
      await store.write(StoreDoc.gameSpider, {'a': 1});
      final late = store.write(StoreDoc.gameSpider, {'a': 2});
      await store.delete(StoreDoc.gameSpider);
      await late;
      expect(await store.read(StoreDoc.gameSpider), isA<Absent>());
      expect(await fileOf(StoreDoc.gameSpider).exists(), isFalse);
      await store.delete(StoreDoc.gameSpider);
    },
  );

  test('unknown extra top-level keys are ignored', () async {
    await Directory('${temp.path}/data').create(recursive: true);
    await fileOf(StoreDoc.settings)
        .writeAsString('{"format":1,"data":{"x":1},"extra":true}');
    expect((await store.read(StoreDoc.settings) as Loaded).data, {'x': 1});
    expect(store.corruptionNotices.value, isEmpty);
  });

  test('a value JSON cannot encode throws for the caller', () {
    expect(
      () => store.write(StoreDoc.settings, {'bad': Object()}),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });

  test(
    'the memory store works behind the same API and is not persistent',
    () async {
      final memory = AppStore.memory();
      expect(await memory.persistent, isFalse);
      expect(await memory.read(StoreDoc.stats), isA<Absent>());
      await memory.write(StoreDoc.stats, {'k': 1});
      expect((await memory.read(StoreDoc.stats) as Loaded).data, {'k': 1});
      await memory.quarantine(StoreDoc.stats, 'x');
      expect(await memory.read(StoreDoc.stats), isA<Absent>());
      expect(memory.corruptionNotices.value, {StoreDoc.stats});
    },
  );

  test(
    'a directory that cannot be used falls back to memory without throwing',
    () async {
      final file = File('${temp.path}/not-a-dir');
      await file.writeAsString('x');
      final store = AppStore.directory(Directory(file.path));
      await store.write(StoreDoc.stats, {'k': 1});
      expect((await store.read(StoreDoc.stats) as Loaded).data, {'k': 1});
      expect(await store.persistent, isFalse);
    },
  );

  test('flush waits for queued writes', () async {
    for (var i = 0; i < 5; i++) {
      store.write(StoreDoc.meta, {'i': i}).ignore();
    }
    await store.flush();
    expect(jsonDecode(await fileOf(StoreDoc.meta).readAsString()), {
      'format': 1,
      'data': {'i': 4},
    });
  });
}
