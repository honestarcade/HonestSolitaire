@Tags(['guard'])
library;

// Signing fails closed, and key material cannot be committed (#14, #33).
//
// The build must refuse, not silently debug-sign, when a release is requested
// without every HS_* variable or when only some are set; and git must ignore
// every file a keystore or its password could arrive in. The .gitignore rule
// is asserted through `git check-ignore`, which applies git's own matching,
// rather than by reading the file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

/// The fail-closed properties [gradle] is missing, by name.
List<String> missingFailClosed(String gradle) {
  final code = gradle
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
  bool has(String pattern) => RegExp(pattern, dotAll: true).hasMatch(code);
  return [
    if (!has(r'System\.getenv\("HS_RELEASE"\)\s*==\s*"1"'))
      'HS_RELEASE is read as exactly "1"',
    if (!has(
      r'if\s*\(\s*hsPresent\.isNotEmpty\(\)\s*&&\s*!hsSigningComplete\s*\)\s*\{\n(?:[ \t][^\n]*\n)*?[ \t]+throw\s+GradleException',
    ))
      'a partial HS_* set throws',
    if (!has(
      r'if\s*\(\s*hsReleaseRequested\s*&&\s*!hsSigningComplete\s*\)\s*\{\n(?:[ \t][^\n]*\n)*?[ \t]+throw\s+GradleException',
    ))
      'HS_RELEASE=1 with a missing variable throws',
    if (!has(
      r'release\s*\{\s*if\s*\(\s*hsSigningComplete\s*\)\s*\{[^}]*signingConfig\s*=\s*signingConfigs\.getByName\("release"\)',
    ))
      'release is upload-signed only when every variable is set',
  ];
}

/// Paths git would ignore, of [paths], per the repository's real rules.
Set<String> ignoredByGit(List<String> paths) {
  final r = Process.runSync('git', [
    'check-ignore',
    '--no-index',
    ...paths,
  ], workingDirectory: repoRoot.path);
  // 0: some ignored; 1: none ignored; anything else is an error.
  if (r.exitCode > 1) throw StateError('git check-ignore: ${r.stderr}');
  return (r.stdout as String)
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toSet();
}

const keyMaterial = [
  'upload.keystore',
  'android/app/upload.keystore',
  'android/release.jks',
  'certs/key.p12',
  'android/key.properties',
  'solitaire-signing-credentials.txt',
];

void main() {
  group('the fail-closed rule, proven both ways', () {
    const complete = r'''
val hsReleaseRequested = System.getenv("HS_RELEASE") == "1"
if (hsPresent.isNotEmpty() && !hsSigningComplete) {
    throw GradleException("$missing is not set")
}
if (hsReleaseRequested && !hsSigningComplete) {
    throw GradleException("$missing is not set")
}
buildTypes {
    release {
        if (hsSigningComplete) {
            signingConfig = signingConfigs.getByName("release")
        } else {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
''';

    test('the complete shape passes', () {
      expect(missingFailClosed(complete), isEmpty);
    });

    test('a missing release refusal is caught', () {
      final weakened = complete.replaceFirst(
        'if (hsReleaseRequested && !hsSigningComplete) {\n'
            '    throw GradleException("\$missing is not set")\n}',
        '',
      );
      expect(weakened, isNot(complete));
      expect(missingFailClosed(weakened), [
        'HS_RELEASE=1 with a missing variable throws',
      ]);
    });

    test('a refusal that only survives in a comment is caught', () {
      final commented = complete.replaceAll('throw Gradle', '// throw Gradle');
      expect(missingFailClosed(commented), hasLength(2));
    });
  });

  group('the real build', () {
    test('android/app/build.gradle.kts fails closed', () {
      final missing = missingFailClosed(
        readFile('android/app/build.gradle.kts'),
      );
      expect(
        missing,
        isEmpty,
        reason: describeOffenders('signing-fail-closed', missing),
      );
    });

    test('git ignores every file key material could arrive in', () {
      final ignored = ignoredByGit(keyMaterial);
      final exposed = keyMaterial.where((p) => !ignored.contains(p)).toList();
      expect(
        exposed,
        isEmpty,
        reason: describeOffenders('key-material-not-ignored', exposed),
      );
    });

    test('positive control: git does not ignore ordinary source', () {
      expect(
        ignoredByGit(['lib/main.dart', 'android/signing/README.md']),
        isEmpty,
      );
    });
  });
}
