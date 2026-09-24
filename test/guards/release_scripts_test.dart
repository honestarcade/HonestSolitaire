@Tags(['guard', 'slow'])
library;

// The release path's two refusals, exercised (#37): ci_version.sh must refuse
// a ref it cannot turn into a version, and verify_upload_cert.sh must refuse a
// bundle signed by any key but the committed one. The certificate case signs a
// throwaway zip with a key made on the spot, so no real key material is used.
// Tagged slow: keytool and jarsigner are JVM start-ups.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

ProcessResult _run(
  String script,
  List<String> args, [
  Map<String, String>? env,
]) => Process.runSync('bash', [
  '${repoRoot.path}/tools/$script',
  ...args,
], environment: env);

/// The JDK tool [name], resolved the way the release scripts resolve keytool.
String jdkTool(String name) {
  final hint = Platform.environment['HS_KEYTOOL'];
  final candidates = [
    if (hint != null) '${File(hint).parent.path}/$name',
    '/opt/homebrew/opt/openjdk@21/bin/$name',
    if (Platform.environment['JAVA_HOME'] != null)
      '${Platform.environment['JAVA_HOME']}/bin/$name',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  final which = Process.runSync('which', [name]);
  if (which.exitCode == 0) return (which.stdout as String).trim();
  throw StateError('guard: no $name — set HS_KEYTOOL or JAVA_HOME');
}

void main() {
  group('ci_version.sh', () {
    test('positive control: a release tag yields its name and code', () {
      final r = _run('ci_version.sh', ['v0.1.0', '12', '1']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(r.stdout, 'name=0.1.0\ncode=1121\n');
    });

    for (final bad in [
      ['main', '12', '1'],
      ['v1.2', '12', '1'],
      ['v01.2.3', '12', '1'],
      ['v1.2.3', '0', '1'],
      ['v1.2.3', '12', '10'],
      ['v1.2.3', '12'],
      ['v1.2.3-rc.01', '12', '1'],
      ['v1.2.3-', '12', '1'],
      ['v1.2.3-rc..1', '12', '1'],
      // A newline would inject a line into the step's output file (#37).
      ['v1.2.3\nx', '12', '1'],
    ]) {
      test('refuses ${bad.join(' ').replaceAll('\n', r'\n')}', () {
        final r = _run('ci_version.sh', bad);
        expect(
          [r.exitCode, '${r.stdout}'.contains('code=')],
          [2, false],
          reason:
              'release-scripts: ci_version.sh accepted ${bad.join(' ')}\n'
              '${r.stdout}${r.stderr}',
        );
      });
    }
  });

  group('verify_upload_cert.sh', () {
    late Directory dir;
    late String keytool;
    late String bundle;
    late String pem;

    setUpAll(() {
      keytool = jdkTool('keytool');
      final jarsigner = jdkTool('jarsigner');
      dir = Directory.systemTemp.createTempSync('hs-cert');
      final ks = '${dir.path}/throwaway.p12';
      void ok(ProcessResult r) {
        if (r.exitCode != 0) throw StateError('${r.stdout}${r.stderr}');
      }

      ok(
        Process.runSync(keytool, [
          '-genkeypair',
          '-keystore',
          ks,
          '-storetype',
          'PKCS12',
          '-storepass',
          'throwaway-pass',
          '-alias',
          'k',
          '-keyalg',
          'RSA',
          '-keysize',
          '2048',
          '-validity',
          '2',
          '-dname',
          'CN=throwaway',
        ]),
      );
      pem = '${dir.path}/throwaway.pem';
      ok(
        Process.runSync(keytool, [
          '-exportcert',
          '-rfc',
          '-keystore',
          ks,
          '-storetype',
          'PKCS12',
          '-storepass',
          'throwaway-pass',
          '-alias',
          'k',
          '-file',
          pem,
        ]),
      );
      File('${dir.path}/payload.txt').writeAsStringSync('not an app');
      ok(
        Process.runSync('zip', [
          '-q',
          'app.aab',
          'payload.txt',
        ], workingDirectory: dir.path),
      );
      bundle = '${dir.path}/app.aab';
      ok(
        Process.runSync(jarsigner, [
          '-keystore',
          ks,
          '-storetype',
          'PKCS12',
          '-storepass',
          'throwaway-pass',
          bundle,
          'k',
        ]),
      );
    });

    tearDownAll(() => dir.deleteSync(recursive: true));

    test('positive control: the signing key\'s own certificate matches', () {
      final r = _run(
        'verify_upload_cert.sh',
        [bundle],
        {'HS_KEYTOOL': keytool, 'HS_UPLOAD_CERT': pem},
      );
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}', contains('MATCH'));
    });

    test('a bundle signed by another key is refused', () {
      final r = _run(
        'verify_upload_cert.sh',
        [bundle],
        {'HS_KEYTOOL': keytool},
      );
      expect(
        [r.exitCode, '${r.stderr}'.contains('MISMATCH')],
        [1, true],
        reason:
            'release-scripts: a foreign-key bundle passed the '
            'certificate check\n${r.stdout}${r.stderr}',
      );
    });
  });
}
