@Tags(['guard'])
library;

// The app's platform surface stays small and offline (#83, invariant 1).
//
// The rules, each proven both ways on inline fixtures and then applied to
// the real files:
//  1. nothing under lib/data/, lib/platform/ or lib/feedback/ names a
//     network API;
//  2. MainActivity.kt's channel handles exactly `filesDir` and `openUrl`,
//     SoundBridge.kt's exactly its six (#101), the channel names match the
//     Dart side, and MainActivity registers exactly those two channels;
//  3. the manifest never sets android:allowBackup="false" (the owner's
//     decision: Android's own backup is the player's setting, not ours);
//  4. the sound bridge plays as a game (USAGE_GAME), checks for another
//     app's audio and never takes audio focus; the activity routes the
//     volume keys to the media stream and pauses the loop in onPause.
//
// The identifier scan matches raw text, comments included — the threat model
// (CLAUDE.md) is an honest edit, not evasion. What this does not cover: a
// network call made from elsewhere in lib/ (the manifest guard and the bundle
// scan own the permission side of that), or a channel method the Kotlin
// handles outside the `when`.

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

/// Identifiers that reach the network. `dart:io` itself is allowed: the
/// store needs `File`.
const networkIdentifiers = [
  'HttpClient',
  'HttpServer',
  'WebSocket',
  'RawSocket',
  'Socket(',
  'Socket.connect',
  'package:http',
  'dart:html',
];

/// Every offending identifier in [source].
List<String> networkUses(String source) => [
  for (final id in networkIdentifiers)
    if (source.contains(id)) id,
];

/// The method names MainActivity.kt's `when (call.method)` branches handle:
/// every quoted string on a `->` line inside the block.
List<String> channelMethods(String kotlin) {
  final start = kotlin.indexOf('when (call.method)');
  if (start < 0) return const [];
  final open = kotlin.indexOf('{', start);
  if (open < 0) return const [];
  // The balanced block, so a branch with its own braces does not end it.
  var depth = 0;
  var end = kotlin.length;
  for (var i = open; i < kotlin.length; i++) {
    if (kotlin[i] == '{') depth++;
    if (kotlin[i] == '}' && --depth == 0) {
      end = i;
      break;
    }
  }
  final body = kotlin.substring(open, end);
  return [
    for (final m in RegExp(r'"([A-Za-z]+)"\s*->').allMatches(body)) m.group(1)!,
  ];
}

const allowedMethods = ['filesDir', 'openUrl'];

/// SoundBridge.kt's whole surface (#101).
const allowedSoundMethods = [
  'load',
  'play',
  'musicStart',
  'musicPause',
  'musicStop',
  'release',
];

const _activity =
    'android/app/src/main/kotlin/com/honestarcade/solitaire/MainActivity.kt';
const _bridge =
    'android/app/src/main/kotlin/com/honestarcade/solitaire/SoundBridge.kt';

/// Every channel name a Kotlin source registers or declares.
List<String> kotlinChannels(String kotlin) => [
  for (final m in RegExp(
    r'MethodChannel\([^,]+,\s*"([^"]+)"\)',
  ).allMatches(kotlin))
    m[1]!,
  for (final m in RegExp(r'const val CHANNEL = "([^"]+)"').allMatches(kotlin))
    m[1]!,
];

/// The facts about the sound bridge and the activity the story pins.
List<String> soundSourceOffenders(String bridge, String activity) => [
  if (!bridge.contains('AudioAttributes.USAGE_GAME'))
    'SoundBridge.kt: no USAGE_GAME',
  if (!bridge.contains('isMusicActive'))
    'SoundBridge.kt: no isMusicActive check',
  if (bridge.contains('requestAudioFocus'))
    'SoundBridge.kt: requests audio focus',
  if (!activity.contains('volumeControlStream = AudioManager.STREAM_MUSIC'))
    'MainActivity.kt: volumeControlStream is not STREAM_MUSIC',
  if (!RegExp(r'override fun onPause\(\) \{[^}]*pauseMusic\(\)')
      .hasMatch(activity))
    'MainActivity.kt: onPause does not pause the music',
];

/// Whether [manifest] sets android:allowBackup to false anywhere.
bool disablesBackup(String manifest) =>
    RegExp(r'''android:allowBackup\s*=\s*["']false["']''')
        .hasMatch(stripXmlComments(manifest));

void main() {
  group('the rules, proven both ways', () {
    test(
      'a store that only uses files passes; one that opens a socket is caught',
      () {
        expect(networkUses("import 'dart:io';\nfinal f = File('x');"), isEmpty);
        expect(networkUses("final c = HttpClient();"), ['HttpClient']);
        expect(networkUses("// TODO: WebSocket sync"), [
          'WebSocket',
        ], reason: 'comments count');
        expect(networkUses("import 'package:http/http.dart' as http;"), [
          'package:http',
        ]);
      },
    );

    test('the channel method list is read from the when block', () {
      const kotlin = '''
                when (call.method) {
                    "filesDir" -> result.success(1)
                    "openUrl" -> result.success(true)
                    else -> result.notImplemented()
                }
''';
      expect(channelMethods(kotlin), ['filesDir', 'openUrl']);
      expect(channelMethods('$kotlin "ping" -> result.success(0)'), [
        'filesDir',
        'openUrl',
      ]);
      const extra = '''
                when (call.method) {
                    "filesDir" -> result.success(1)
                    "openUrl" -> result.success(true)
                    "upload" -> result.success(true)
                    else -> result.notImplemented()
                }
''';
      expect(channelMethods(extra), contains('upload'));
    });

    test('the sound sources are read for their facts', () {
      const bridge =
          'setUsage(AudioAttributes.USAGE_GAME) manager.isMusicActive';
      const activity =
          'volumeControlStream = AudioManager.STREAM_MUSIC\n'
          'override fun onPause() {\n sound?.pauseMusic()\n super.onPause()\n }';
      expect(soundSourceOffenders(bridge, activity), isEmpty);
      expect(
        soundSourceOffenders('$bridge requestAudioFocus(', activity).single,
        contains('focus'),
      );
      expect(
        soundSourceOffenders(
          bridge.replaceAll('isMusicActive', 'x'),
          activity,
        ).single,
        contains('isMusicActive'),
      );
      expect(
        soundSourceOffenders(
          bridge,
          activity.replaceAll('STREAM_MUSIC', 'STREAM_RING'),
        ).single,
        contains('volumeControlStream'),
      );
      expect(
        soundSourceOffenders(
          bridge,
          'volumeControlStream = AudioManager.STREAM_MUSIC',
        ).single,
        contains('onPause'),
      );
      expect(
        kotlinChannels('MethodChannel(m, "a/b")\nconst val CHANNEL = "a/c"'),
        ['a/b', 'a/c'],
      );
    });

    test('allowBackup false is caught, in either quote, not in a comment', () {
      expect(
        disablesBackup('<application android:allowBackup="false">'),
        isTrue,
      );
      expect(
        disablesBackup("<application android:allowBackup='false'>"),
        isTrue,
      );
      expect(
        disablesBackup('<application android:allowBackup="true">'),
        isFalse,
      );
      expect(
        disablesBackup('<!-- android:allowBackup="false" -->\n<application>'),
        isFalse,
      );
      expect(disablesBackup('<application>'), isFalse);
    });
  });

  group('the real files', () {
    for (final dir in ['lib/data', 'lib/platform', 'lib/feedback']) {
      test('$dir names no network API', () {
        final files = filesUnder(dir)
            .where((p) => p.endsWith('.dart'))
            .toList();
        expect(
          files,
          isNotEmpty,
          reason: 'platform-surface: $dir has no Dart files to check',
        );
        final offenders = [
          for (final path in files)
            for (final id in networkUses(readFile(path))) '$path: $id',
        ];
        expect(
          offenders,
          isEmpty,
          reason: describeOffenders('platform-surface', offenders),
        );
      });
    }

    test('MainActivity.kt handles exactly filesDir and openUrl', () {
      final methods = channelMethods(
        readFile(
          'android/app/src/main/kotlin/com/honestarcade/solitaire/MainActivity.kt',
        ),
      );
      expect(
        methods..sort(),
        [...allowedMethods]..sort(),
        reason:
            'platform-surface: the channel handles $methods; the surface is '
            'exactly $allowedMethods — a new method is a new capability, which '
            'is a conversation, not an edit',
      );
    });

    test('SoundBridge.kt handles exactly its six methods', () {
      final methods = channelMethods(readFile(_bridge));
      expect(
        methods..sort(),
        [...allowedSoundMethods]..sort(),
        reason:
            'platform-surface: the sound channel handles $methods; the surface '
            'is exactly $allowedSoundMethods — a new method is a new capability',
      );
    });

    test('the channel names match on both sides, and the activity registers exactly two', () {
      final activity = readFile(_activity);
      final bridge = readFile(_bridge);
      final registered = RegExp(r'MethodChannel\(').allMatches(activity).length;
      expect(
        registered,
        2,
        reason:
            'platform-surface: MainActivity registers $registered channels, not 2',
      );
      expect(
        kotlinChannels(activity),
        contains('honestsolitaire/platform'),
        reason: 'platform-surface: the platform channel name differs from lib/platform/platform_channel.dart',
      );
      expect(
        readFile('lib/platform/platform_channel.dart'),
        contains("'honestsolitaire/platform'"),
      );
      expect(kotlinChannels(bridge), [
        'honestsolitaire/sound',
      ], reason: 'platform-surface: the sound channel name differs');
      expect(
        readFile('lib/feedback/sound_player.dart'),
        contains("'honestsolitaire/sound'"),
      );
    });

    test('the sound bridge plays as a game, defers to other audio, never takes focus; the activity routes volume and pauses', () {
      final offenders = soundSourceOffenders(
        readFile(_bridge),
        readFile(_activity),
      );
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('platform-surface', offenders),
      );
    });

    test('the manifest leaves Android backup to the player', () {
      expect(
        disablesBackup(readFile('android/app/src/main/AndroidManifest.xml')),
        isFalse,
        reason:
            'platform-surface: the manifest sets android:allowBackup="false"; '
            'the owner decided (2026-09-24) that Android backup is the player\'s choice',
      );
    });
  });
}
