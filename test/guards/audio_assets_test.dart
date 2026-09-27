@Tags(['guard'])
library;

// Every sound the app plays is a real, licensed clip: a short 44.1 kHz mono
// 16-bit WAV named in lib/feedback/clips.dart, recorded in
// assets/audio/LICENSES.md, and bundled one by one (#98). Ported from Honest
// Sudoku's audio guard without its placeholder machinery.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'audio_rules.dart';
import 'repo_files.dart';

String _describe(String rule, List<String> offenders) =>
    '$rule: ${offenders.length} offender(s)\n  ${offenders.join('\n  ')}';

/// A WAV of [seconds] of silence.
List<int> _wav(
  double seconds, {
  int rate = 44100,
  int channels = 1,
  int bits = 16,
  int format = 1,
  int riffSlack = 0,
}) {
  final data = (seconds * rate).round() * channels * bits ~/ 8;
  final b = ByteData(44 + data);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data + riffSlack, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, format, Endian.little);
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * channels * bits ~/ 8, Endian.little);
  b.setUint16(32, channels * bits ~/ 8, Endian.little);
  b.setUint16(34, bits, Endian.little);
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  return b.buffer.asUint8List();
}

const _clipsSource = '''
const Map<Clip, ClipSpec> clips = {
  Clip.deal: ClipSpec('assets/audio/deal.wav', loop: false),
  Clip.music: ClipSpec('assets/audio/music.wav', loop: true),
};
''';

String _licences(Iterable<String> names) =>
    '# Audio\n\n## Licensed\n\n| File | Source | Licence |\n|---|---|---|\n'
    '${names.map((n) => '| `$n` | ElevenLabs | Creator plan |\n').join()}';

void main() {
  group('the rules', () {
    final declared = declaredClips(_clipsSource);
    final clip = _wav(.1);
    final loop = _wav(30);
    Map<String, List<int>> files() => {
      'deal.wav': clip,
      'music.wav': loop,
      'LICENSES.md': const [],
      'PROMPTS.md': const [],
    };
    List<Offender> check(Map<String, List<int>> f, String licences) =>
        audioOffenders(f, licences, declared);

    test('the clip list is read from clips.dart', () {
      expect(declared.map((c) => c.name), ['deal.wav', 'music.wav']);
      expect(declared.last.loop, isTrue);
      expect(declaredClips('nothing here'), isEmpty);
    });

    test('two recorded clips pass; a stray file, a missing clip and a missing row fail, named', () {
      expect(check(files(), _licences(['deal.wav', 'music.wav'])), isEmpty);
      expect(
        check({
          ...files(),
          'mystery.wav': clip,
        }, _licences(['deal.wav', 'music.wav'])).single.path,
        'mystery.wav',
      );
      final missing = files()..remove('deal.wav');
      expect(check(missing, _licences(['music.wav'])).single, (
        path: 'deal.wav',
        message: 'missing',
      ));
      expect(
        check(files(), _licences(['music.wav'])).single.message,
        contains('Licensed'),
      );
      expect(
        check(
          files(),
          _licences(['deal.wav', 'music.wav', 'ghost.wav']),
        ).single.message,
        contains('absent'),
      );
      expect(
        check(
          files()..remove('PROMPTS.md'),
          _licences(['deal.wav', 'music.wav']),
        ).single.path,
        'PROMPTS.md',
      );
    });

    test('the format: PCM 16-bit 44.1 kHz mono, agreeing sizes, non-empty, within limits', () {
      expect(
        wavProblems(_wav(.1, rate: 48000), loop: false).single,
        contains('48000'),
      );
      expect(
        wavProblems(_wav(.1, channels: 2), loop: false).single,
        contains('mono'),
      );
      expect(
        wavProblems(_wav(.1, bits: 8), loop: false).single,
        contains('16-bit'),
      );
      expect(
        wavProblems(_wav(.1, format: 3), loop: false).single,
        contains('PCM'),
      );
      expect(wavProblems([1, 2, 3], loop: false).single, contains('RIFF'));
      expect(wavProblems(_wav(0), loop: false).single, contains('empty'));
      expect(
        wavProblems(_wav(.1, riffSlack: 4), loop: false).single,
        contains('RIFF size'),
      );
      expect(
        wavProblems(_wav(2), loop: false),
        isEmpty,
        reason: '2.000 s is allowed',
      );
      expect(wavProblems(_wav(2.1), loop: false).single, contains('over 2 s'));
      expect(
        wavProblems(_wav(3, channels: 2), loop: false),
        contains(contains('over ${250 * 1024}')),
      );
      expect(wavProblems(_wav(30), loop: true), isEmpty);
      expect(wavProblems(_wav(28), loop: true).single, contains('under 29 s'));
      expect(wavProblems(_wav(32), loop: true).single, contains('over 31 s'));
    });

    test('the pubspec bundles each clip, never the directory', () {
      const ok =
          'flutter:\n  assets:\n    - assets/audio/deal.wav\n    - assets/audio/music.wav\n';
      expect(pubspecAudioOffenders(ok, declared), isEmpty);
      expect(
        pubspecAudioOffenders(
          ok.replaceFirst('    - assets/audio/deal.wav\n', ''),
          declared,
        ).single,
        contains('deal.wav'),
      );
      expect(
        pubspecAudioOffenders(
          'flutter:\n  assets:\n    - assets/audio/\n',
          declared,
        ),
        hasLength(3),
      );
    });
  });

  group('the repository', () {
    final declared = declaredClips(readFile('lib/feedback/clips.dart'));

    test('audio-assets: every clip the app plays is present, licensed and well-formed', () {
      final dir = Directory('${repoRoot.path}/assets/audio');
      final files = {
        for (final f in dir.listSync().whereType<File>())
          f.uri.pathSegments.last: f.readAsBytesSync(),
      };
      final offenders = audioOffenders(
        files,
        readFile('assets/audio/LICENSES.md'),
        declared,
      );
      expect(
        offenders,
        isEmpty,
        reason: _describe('audio-assets', [
          for (final o in offenders) 'assets/audio/${o.path}: ${o.message}',
        ]),
      );
    });

    test('audio-declared: pubspec.yaml bundles each clip one by one', () {
      final offenders = pubspecAudioOffenders(
        stripYamlComments(readFile('pubspec.yaml')),
        declared,
      );
      expect(
        offenders,
        isEmpty,
        reason: _describe('audio-declared', offenders),
      );
    });

    test('audio-readme: the README names the licence record and says the clips are not MIT', () {
      final paragraph = RegExp(r'\*\*Audio\.\*\*[^\n]*(\n[^\n]+)*')
          .firstMatch(readFile('README.md'))
          ?.group(0);
      expect(
        paragraph,
        isNotNull,
        reason: 'audio-readme: no **Audio.** paragraph in the licence section',
      );
      expect(
        paragraph,
        contains('assets/audio/LICENSES.md'),
        reason: 'audio-readme: the paragraph does not name assets/audio/LICENSES.md',
      );
      expect(
        paragraph,
        contains('not covered by the MIT'),
        reason:
            'audio-readme: the paragraph does not say the clips are not MIT',
      );
    });
  });
}
