// The audio-assets rules (#98), as pure functions over file names, bytes,
// the licence record and the clip list. Ported from Honest Sudoku's
// audio_rules.dart (its #49) without its placeholder machinery.
library;

/// One refusal, naming the file.
typedef Offender = ({String path, String message});

/// A clip the app plays, as `lib/feedback/clips.dart` declares it.
typedef ClipEntry = ({String name, String asset, bool loop});

/// The files tolerated beside the clips.
const List<String> kRecords = ['LICENSES.md', 'PROMPTS.md'];

/// The longest and largest an effect may be.
const Duration kMaxClip = Duration(seconds: 2);
const int kMaxClipBytes = 250 * 1024;

/// The loop's length window and size cap.
const Duration kMinLoop = Duration(seconds: 29);
const Duration kMaxLoop = Duration(seconds: 31);
const int kMaxLoopBytes = 3 * 1024 * 1024;

/// The clips `clips.dart` names: every `ClipSpec('assets/audio/x.wav',
/// loop: …)` in [source].
List<ClipEntry> declaredClips(String source) => [
  for (final m in RegExp(
    r"ClipSpec\(\s*'(assets/audio/([\w-]+)\.wav)',\s*loop:\s*(true|false)\s*\)",
  ).allMatches(source))
    (name: '${m[2]}.wav', asset: m[1]!, loop: m[3] == 'true'),
];

/// What a clip must be: RIFF/WAVE PCM, 16-bit, 44.1 kHz, mono, chunk sizes
/// that agree with the file, non-empty data, within its kind's length and
/// size limits.
List<String> wavProblems(List<int> bytes, {required bool loop}) {
  final out = <String>[];
  final maxBytes = loop ? kMaxLoopBytes : kMaxClipBytes;
  if (bytes.length > maxBytes) {
    out.add('${bytes.length} bytes, over $maxBytes');
  }
  String tag(int at) => at + 4 <= bytes.length
      ? String.fromCharCodes(bytes.sublist(at, at + 4))
      : '';
  int u16(int at) => bytes[at] | bytes[at + 1] << 8;
  int u32(int at) => u16(at) | u16(at + 2) << 16;
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    return [...out, 'not a RIFF/WAVE file'];
  }
  if (u32(4) != bytes.length - 8) {
    out.add(
      'RIFF size ${u32(4)} does not match the file (${bytes.length - 8})',
    );
  }
  int? format, channels, rate, bits, dataBytes;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = tag(at);
    final size = u32(at + 4);
    if (at + 8 + size > bytes.length) {
      out.add('chunk $id of $size bytes runs past the end of the file');
      break;
    }
    if (id == 'fmt ' && at + 24 <= bytes.length) {
      format = u16(at + 8);
      channels = u16(at + 10);
      rate = u32(at + 12);
      bits = u16(at + 22);
    } else if (id == 'data') {
      dataBytes = size;
    }
    at += 8 + size + size % 2;
  }
  if (format == null || dataBytes == null) {
    return [...out, 'no fmt or data chunk'];
  }
  if (dataBytes == 0) out.add('empty data chunk');
  if (format != 1) out.add('format $format, not PCM');
  if (bits != 16) out.add('$bits-bit, not 16-bit');
  if (rate != 44100) out.add('$rate Hz, not 44100 Hz');
  if (channels != 1) out.add('$channels channels, not mono');
  if (channels! > 0 && bits! > 0 && rate! > 0) {
    final micros = dataBytes * 1000000 ~/ (channels * bits ~/ 8 * rate);
    if (loop) {
      if (micros < kMinLoop.inMicroseconds) {
        out.add(
          '${micros / 1000000} s long, under ${kMinLoop.inSeconds} s for a loop',
        );
      }
      if (micros > kMaxLoop.inMicroseconds) {
        out.add(
          '${micros / 1000000} s long, over ${kMaxLoop.inSeconds} s for a loop',
        );
      }
    } else if (micros > kMaxClip.inMicroseconds) {
      out.add('${micros / 1000000} s long, over ${kMaxClip.inSeconds} s');
    }
  }
  return out;
}

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// The Licensed table's clips, each with a source, a licence and the date
/// it was generated (#115): rows of the first markdown table under
/// `## Licensed` whose four cells are non-empty, the last a `YYYY-MM-DD`.
Set<String> licensedClips(String licences) {
  // Sliced by hand: Dart's RegExp has no \Z, and a lookahead for the next
  // heading fails when Licensed is the last section.
  final start = RegExp(
    r'^## Licensed\s*$',
    multiLine: true,
  ).firstMatch(licences);
  if (start == null) return const {};
  final rest = licences.substring(start.end);
  final next = RegExp(r'^## ', multiLine: true).firstMatch(rest);
  final section = next == null ? rest : rest.substring(0, next.start);
  final out = <String>{};
  var inTable = false;
  for (final line in section.split('\n')) {
    final cells = line.trim();
    if (!cells.startsWith('|')) {
      if (inTable) break; // only the first table counts
      continue;
    }
    inTable = true;
    final parts = cells
        .substring(1, cells.length - (cells.endsWith('|') ? 1 : 0))
        .split('|')
        .map((c) => c.trim())
        .toList();
    if (parts.length != 4 || parts.any((c) => c.isEmpty)) continue;
    final name = parts[0].replaceAll('`', '');
    if (name == 'File' || name.startsWith('---')) continue;
    if (!_isoDate.hasMatch(parts[3])) continue;
    out.add(name);
  }
  return out;
}

/// Every rule over the directory's [files] (name → bytes), [licences] and
/// the [declared] clips.
List<Offender> audioOffenders(
  Map<String, List<int>> files,
  String licences,
  List<ClipEntry> declared,
) {
  final out = <Offender>[];
  final licensed = licensedClips(licences);
  final byName = {for (final c in declared) c.name: c};
  if (declared.isEmpty) {
    out.add((path: 'clips.dart', message: 'declares no clips'));
  }
  for (final record in kRecords) {
    if (!files.containsKey(record)) {
      out.add((path: record, message: 'the record is missing'));
    }
  }
  for (final MapEntry(key: name, value: bytes) in files.entries) {
    if (kRecords.contains(name)) continue;
    final clip = byName[name];
    if (clip == null) {
      out.add((path: name, message: 'not a clip the app plays (clips.dart)'));
      continue;
    }
    if (!licensed.contains(name)) {
      out.add((
        path: name,
        message: 'no dated source and licence in the Licensed table',
      ));
    }
    for (final problem in wavProblems(bytes, loop: clip.loop)) {
      out.add((path: name, message: problem));
    }
  }
  for (final clip in declared) {
    if (!files.containsKey(clip.name)) {
      out.add((path: clip.name, message: 'missing'));
    }
  }
  for (final name in licensed) {
    if (!files.containsKey(name)) {
      out.add((path: name, message: 'licensed but absent'));
    }
  }
  return out;
}

/// The clips [declared] that the pubspec's `flutter: assets:` list (comments
/// stripped) does not bundle one by one, plus a directory entry, which would
/// bundle the records too.
List<String> pubspecAudioOffenders(
  String pubspecNoComments,
  List<ClipEntry> declared,
) {
  final block =
      RegExp(
        r'^  assets:\n((?:    - .*\n)*)',
        multiLine: true,
      ).firstMatch(pubspecNoComments)?[1] ??
      '';
  final listed = {
    for (final m in RegExp(r'^    - (.*)$', multiLine: true).allMatches(block))
      m[1]!.trim(),
  };
  return [
    for (final clip in declared)
      if (!listed.contains(clip.asset))
        '${clip.asset}: not in flutter: assets:',
    if (listed.contains('assets/audio/'))
      'assets/audio/: the directory would bundle LICENSES.md and PROMPTS.md',
  ];
}
