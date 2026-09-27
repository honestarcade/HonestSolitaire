@Tags(['guard'])
library;

// The app's platform surface stays small and offline (#83, invariant 1).
//
// Three rules, each proven both ways on inline fixtures and then applied to
// the real files:
//  1. nothing under lib/data/ or lib/platform/ names a network API;
//  2. MainActivity.kt's channel handles exactly `filesDir` and `openUrl`;
//  3. the manifest never sets android:allowBackup="false" (the owner's
//     decision: Android's own backup is the player's setting, not ours).
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
  final block = kotlin.substring(start);
  final end = block.indexOf('\n                }');
  final body = end < 0 ? block : block.substring(0, end);
  return [
    for (final m in RegExp(r'"([A-Za-z]+)"\s*->').allMatches(body)) m.group(1)!,
  ];
}

const allowedMethods = ['filesDir', 'openUrl'];

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
    for (final dir in ['lib/data', 'lib/platform']) {
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
