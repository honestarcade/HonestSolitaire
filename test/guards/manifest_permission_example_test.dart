@Tags(['guard'])
library;

// Worked example: a manifest/permission-shaped guard.
//
// This is the SOURCE half of Honest Sudoku's no-network invariant — it reads
// the Android manifest as text and asserts no `<uses-permission>` element is
// declared. It is deliberately the simple half. The other half — proving the
// same thing about the actual BUILT bundle, where a plugin's merged manifest
// can hide a permission this file never sees — is `tools/check_aab.sh`,
// already ported and already wired into `tools/gate.sh` step 6. Both exist
// because they catch different failures: this one is fast and runs on every
// `flutter test`; that one is the artefact truth and runs once per gate.
//
// The pattern to copy for your own manifest/permission-shaped rules:
//   1. Read the real file (`readFile`, never a fixture standing in for it).
//   2. Assert the POSITIVE (no permission elements) AND, where your project
//      adds one on purpose, assert the ALLOWED one is still exactly what you
//      expect — a permission guard that only ever asserts "empty" cannot
//      tell "clean" from "the parser stopped seeing anything" (see #80/#87
//      in Honest Sudoku's own history for what that mistake cost there).
//   3. Prove the guard can fail: this file's second test builds a fixture
//      WITH a permission and asserts the same rule catches it. A guard with
//      no failing test is unproven.

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

/// The rule: no `<uses-permission ...>` element anywhere in [manifestXml].
/// Returns the offending lines, so a failure names what it found.
List<String> usesPermissionOffenders(String manifestXml) {
  final withoutComments = stripXmlComments(manifestXml);
  final offenders = <String>[];
  for (final line in withoutComments.split('\n')) {
    if (RegExp(r'<uses-permission\b').hasMatch(line)) {
      offenders.add(line.trim());
    }
  }
  return offenders;
}

/// `<permission>`, `<permission-group>` and `<permission-tree>` elements in
/// [manifestXml]: a declaration is not a request, but invariant 1 wants
/// neither, and the bundle scan treats a declaration as an offender too.
List<String> permissionElementOffenders(String manifestXml) =>
    RegExp(r'<permission(?:-group|-tree)?\b[^>]*>')
        .allMatches(stripXmlComments(manifestXml))
        .map((m) => m.group(0)!)
        .toList();

/// Build-time removal rules (`tools:node="remove"` / `"removeAll"`). CLAUDE.md
/// invariant 1 forbids them: a plugin that declares a permission is not
/// adopted, rather than adopted and then stripped.
List<String> removalRuleOffenders(String manifestXml) =>
    RegExp(r'tools:node\s*=\s*"(?:remove|removeAll)"')
        .allMatches(stripXmlComments(manifestXml))
        .map((m) => m.group(0)!)
        .toList();

/// Every AndroidManifest.xml under android/ that a build would read — on disk,
/// tracked or not, build output excluded.
List<String> sourceManifests() =>
    filesUnder('android')
        .where((p) => p.endsWith('AndroidManifest.xml'))
        .where((p) => !p.contains('/build/') && !p.contains('/.gradle/'))
        .toList();

void main() {
  group('the real manifest as it stands', () {
    test('declares no uses-permission element', () {
      final manifest = readFile('android/app/src/main/AndroidManifest.xml');
      final offenders = usesPermissionOffenders(manifest);
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('permission-guard', offenders),
      );
    });

    test('declares no permission element', () {
      final manifest = readFile('android/app/src/main/AndroidManifest.xml');
      final offenders = permissionElementOffenders(manifest);
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('manifest-permission-element', offenders),
      );
    });

    test('no manifest under android/ carries a removal rule', () {
      final manifests = sourceManifests();
      expect(manifests, contains('android/app/src/main/AndroidManifest.xml'));
      final offenders = [
        for (final path in manifests)
          for (final rule in removalRuleOffenders(readFile(path)))
            '$path: $rule',
      ];
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('manifest-removal-rule', offenders),
      );
    });
  });

  group('the rule itself, proven both ways', () {
    test('a clean manifest passes', () {
      const clean = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="app">
        <activity android:name=".MainActivity" />
    </application>
</manifest>
''';
      expect(usesPermissionOffenders(clean), isEmpty);
    });

    // The complement: this is the test that would have caught a guard that
    // always returns an empty list. A guard proven only on the clean input
    // is not proven at all.
    test('a manifest declaring INTERNET is caught, not waved through', () {
      const dirty = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="app" />
</manifest>
''';
      final offenders = usesPermissionOffenders(dirty);
      expect(offenders, hasLength(1));
      expect(offenders.first, contains('android.permission.INTERNET'));
    });

    test('a commented-out permission does not count', () {
      const commented = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- <uses-permission android:name="android.permission.INTERNET" /> -->
    <application android:label="app" />
</manifest>
''';
      expect(usesPermissionOffenders(commented), isEmpty);
    });
  });

  group('the element and removal rules, proven both ways', () {
    test('permission declarations of all three kinds are caught', () {
      const dirty = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <permission android:name="com.x.P" />
    <permission-group android:name="com.x.G" />
    <permission-tree android:name="com.x.T" />
    <!-- <permission android:name="com.x.Commented" /> -->
    <application android:label="app" />
</manifest>
''';
      expect(permissionElementOffenders(dirty), hasLength(3));
      expect(
        permissionElementOffenders('<manifest><application/></manifest>'),
        isEmpty,
      );
    });

    test('a removal rule is caught, a commented one is not', () {
      const dirty = '''
<uses-permission android:name="android.permission.INTERNET" tools:node="remove" />
<uses-permission android:name="android.permission.CAMERA" tools:node = "removeAll" />
<!-- <uses-permission tools:node="remove" /> -->
<activity tools:node="merge" />
''';
      expect(removalRuleOffenders(dirty), hasLength(2));
    });
  });
}
