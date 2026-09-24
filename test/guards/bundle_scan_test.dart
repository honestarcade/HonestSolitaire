@Tags(['guard', 'slow'])
library;

// tools/check_aab.sh is the only check on the built artefact (invariant 1), so
// it must be seen to fail (#30). Each case zips a synthetic
// base/manifest/AndroidManifest.xml whose readable strings have the shapes the
// real protobuf manifest yields — element names followed by a packed byte, the
// android namespace, `name`, a length-prefixed value — and runs the real
// script on it. Tagged slow: every case spawns zip and bash.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

const _ns = '*http://schemas.android.com/apk/res/android';
const _pkg = 'com.honestarcade.solitaire';

List<String> _selfPermission(String pkg) => [
  'permission"|',
  _ns,
  'name',
  'C$pkg.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION(',
  '"W',
  _ns,
  'protectionLevel',
  'signature"',
  '(',
  'uses-permission"|',
  _ns,
  'name',
  'C$pkg.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION(',
  '*',
];

List<String> _request(String name) => [
  'uses-permission"|',
  _ns,
  'name',
  '$name(', // a short value's length byte is not printable
  '*',
];

List<String> _declare(String name) => [
  'permission"|',
  _ns,
  'name',
  '$name(', // a short value's length byte is not printable
  '"W',
  _ns,
  'protectionLevel',
  'normal"',
  '(',
];

/// A manifest's readable strings, in the order the real one yields them.
List<String> manifest({String pkg = _pkg, List<String> extra = const []}) => [
  'manifest"%',
  'package',
  '$pkg"K',
  ..._selfPermission(pkg),
  ...extra,
  'meta-data"',
  _ns,
  'name',
  'flutterEmbedding(',
  '"V',
  _ns,
  'permission',
  'android.permission.DUMP(',
  '*',
];

class ScanResult {
  ScanResult(this.exitCode, this.output);
  final int exitCode;
  final String output;
}

ScanResult scan(List<String> strings) {
  final dir = Directory.systemTemp.createTempSync('hs-bundle-scan');
  try {
    final entry = File('${dir.path}/base/manifest/AndroidManifest.xml')
      ..createSync(recursive: true);
    // NUL between strings, as the protobuf's non-printable bytes are.
    entry.writeAsBytesSync([
      for (final s in strings) ...[...s.codeUnits, 0],
    ]);
    final zip = Process.runSync('zip', [
      '-q',
      '-r',
      'app.aab',
      'base',
    ], workingDirectory: dir.path);
    if (zip.exitCode != 0) throw StateError('zip failed: ${zip.stderr}');
    final env = Map<String, String>.of(Platform.environment)
      ..remove('APP_PACKAGE_ID');
    final r = Process.runSync(
      'bash',
      ['${repoRoot.path}/tools/check_aab.sh', '${dir.path}/app.aab'],
      environment: env,
      includeParentEnvironment: false,
    );
    return ScanResult(r.exitCode, '${r.stdout}${r.stderr}');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  test('positive control: a clean Flutter bundle passes', () {
    final r = scan(manifest());
    expect(r.exitCode, 0, reason: r.output);
    expect(r.output, contains('no permissions declared (package $_pkg)'));
  });

  test('a requested android permission fails the scan', () {
    final r = scan(manifest(extra: _request('android.permission.INTERNET')));
    expect(
      [
        r.exitCode,
        r.output.contains('PERMISSION: android.permission.INTERNET'),
      ],
      [1, true],
      reason: 'bundle-scan: an INTERNET request was not refused\n${r.output}',
    );
  });

  test('a requested non-android permission fails the scan', () {
    final r = scan(manifest(extra: _request('com.evilads.sdk.TRACK_USER')));
    expect(
      [r.exitCode, r.output.contains('PERMISSION: com.evilads.sdk.TRACK_USER')],
      [1, true],
      reason:
          'bundle-scan: a third-party permission request was not refused\n'
          '${r.output}',
    );
  });

  test('a declared foreign permission fails the scan', () {
    final r = scan(manifest(extra: _declare('com.evilads.sdk.P')));
    expect(
      [r.exitCode, r.output.contains('com.evilads.sdk.P (declared)')],
      [1, true],
      reason: 'bundle-scan: a declared permission was not refused\n${r.output}',
    );
  });

  test('a wrong package is reported as the package, with exit 2', () {
    final r = scan(manifest(pkg: 'com.honestarcade.sudoku'));
    expect(
      [
        r.exitCode,
        r.output.contains('PACKAGE MISSING'),
        r.output.contains('PERMISSION:'),
      ],
      [2, true, false],
      reason:
          'bundle-scan: a wrong package was not diagnosed as one\n'
          '${r.output}',
    );
  });
}
