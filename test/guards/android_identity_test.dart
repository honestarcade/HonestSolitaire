@Tags(['guard'])
library;

// The app's identity (#13, #28): the package id every build, scan and upload
// names, the launcher label, the portrait lock, minSdk, and Android as the
// only platform. Each rule is a pure function over text, proven both ways on
// inline fixtures, then applied to the real files.

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

const packageId = 'com.honestarcade.solitaire';
const appLabel = 'Honest Solitaire';
const minSdk = 24;

/// Every studio or template-example package literal in [text]
/// that is not [expected]. Segments are lower-case, so a suffix such as
/// `.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` ends the match.
List<String> foreignPackageIds(String text, String expected) =>
    RegExp(r'\bcom\.(?:honestarcade|example)(?:\.[a-z_][a-z0-9_]*)+')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((id) => id != expected)
        .toList();

/// The value of `name = "…"` / `name = N` in a Gradle Kotlin script.
String? gradleValue(String gradle, String name) {
  final m = RegExp(
    '^\\s*$name\\s*=\\s*"?([^"\\s]+)"?\\s*\$',
    multiLine: true,
  ).firstMatch(gradle);
  return m?.group(1);
}

/// The `<activity>` element for `.MainActivity`, comments removed.
String? mainActivityElement(String manifest) {
  final m = RegExp(
    r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>',
    dotAll: true,
  ).firstMatch(stripXmlComments(manifest));
  return m?.group(0);
}

String? applicationLabel(String manifest) => RegExp(
  r'<application\b[^>]*android:label="([^"]*)"',
  dotAll: true,
).firstMatch(stripXmlComments(manifest))?.group(1);

// Built by concatenation so this file does not match its own rule.
final templateTokens = [
  '<PLACE'
      'HOLDER>',
  'your'
      '_app',
  'com.'
      'example.',
];

void main() {
  group('the rules, proven both ways', () {
    test('a foreign package literal is found, the expected one is not', () {
      const text = 'a com.honestarcade.solitaire b com.honestarcade.sudoku';
      expect(foreignPackageIds(text, packageId), ['com.honestarcade.sudoku']);
      expect(foreignPackageIds('x com.honestarcade.solitaire', packageId), []);
    });

    test('an activity without the portrait lock is visible as such', () {
      const locked =
          '<activity android:name=".MainActivity" '
          'android:screenOrientation="portrait">';
      const unlocked = '<activity android:name=".MainActivity">';
      expect(mainActivityElement(locked), contains('portrait'));
      expect(mainActivityElement(unlocked), isNot(contains('portrait')));
      expect(
        mainActivityElement(
          '<!-- <activity android:name=".MainActivity" '
          'android:screenOrientation="portrait"> -->'
          '<activity android:name=".MainActivity">',
        ),
        isNot(contains('portrait')),
      );
    });

    test('gradleValue reads quoted and bare values', () {
      const gradle = '  namespace = "a.b"\n        minSdk = 21\n';
      expect(gradleValue(gradle, 'namespace'), 'a.b');
      expect(gradleValue(gradle, 'minSdk'), '21');
      expect(gradleValue(gradle, 'applicationId'), isNull);
    });
  });

  group('the real app', () {
    test('build.gradle.kts names the package and minSdk', () {
      final gradle = readFile('android/app/build.gradle.kts');
      expect(
        [
          gradleValue(gradle, 'namespace'),
          gradleValue(gradle, 'applicationId'),
        ],
        [packageId, packageId],
        reason: 'android-identity: namespace/applicationId is not $packageId',
      );
      expect(
        gradleValue(gradle, 'minSdk'),
        '$minSdk',
        reason: 'android-identity: minSdk is not $minSdk',
      );
    });

    test('MainActivity lives in the package', () {
      final kt = readFile(
        'android/app/src/main/kotlin/com/honestarcade/solitaire/MainActivity.kt',
      );
      expect(
        kt,
        contains('package $packageId\n'),
        reason: 'android-identity: MainActivity.kt is not in $packageId',
      );
    });

    test('the launcher label and the portrait lock', () {
      final manifest = readFile('android/app/src/main/AndroidManifest.xml');
      expect(
        applicationLabel(manifest),
        appLabel,
        reason: 'android-identity: the launcher label is not "$appLabel"',
      );
      expect(
        mainActivityElement(manifest),
        contains('android:screenOrientation="portrait"'),
        reason: 'android-identity: MainActivity is not locked to portrait',
      );
    });

    test('every script and workflow names the same package', () {
      final files = [
        'tools/check_aab.sh',
        ...trackedFilesUnder('.github/workflows'),
      ];
      final offenders = <String>[];
      for (final path in files) {
        for (final id in foreignPackageIds(readFile(path), packageId)) {
          offenders.add('$path: $id');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('android-identity-package', offenders),
      );
      expect(
        readFile('tools/check_aab.sh'),
        contains('PACKAGE="\${APP_PACKAGE_ID:-$packageId}"'),
        reason: 'android-identity: check_aab.sh does not default to $packageId',
      );
    });

    test('Android is the only platform', () {
      final present = [
        'ios',
        'macos',
        'linux',
        'windows',
        'web',
      ].where(pathExists).toList();
      expect(
        present,
        isEmpty,
        reason: describeOffenders('android-identity-platform', present),
      );
    });

    test('no template placeholder survives in a tracked file', () {
      final offenders = <String>[];
      for (final path in trackedFilesUnder('.')) {
        if (path.endsWith('.png') || path.endsWith('.lock')) continue;
        final text = readFile(path);
        for (final token in templateTokens) {
          if (text.contains(token)) offenders.add('$path: $token');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('android-identity-template', offenders),
      );
    });
  });
}
