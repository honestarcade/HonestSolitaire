@Tags(['guard', 'slow'])
library;

// The Play setup scripts' refusals, exercised (#41). Each case runs the real
// script on a PATH holding only a few coreutils and stubs of gcloud, gh and
// keytool that record their arguments, so no real account, repository or
// keystore can be reached. Tagged slow: every case spawns bash.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

const _utilities = [
  'bash',
  'sh',
  'dirname',
  'head',
  'tr',
  'sed',
  'awk',
  'grep',
  'base64',
  'cat',
  'rm',
  'cut',
  'env',
];

const _gcloud = r'''#!/bin/sh
echo "gcloud $*" >> "$STUB_LOG"
case "$*" in
  "auth list"*) [ -n "${GCLOUD_ACCOUNT:-}" ] && echo "$GCLOUD_ACCOUNT"; exit 0 ;;
esac
exit 1
''';

const _gh = r'''#!/bin/sh
echo "gh $*" >> "$STUB_LOG"
cat > /dev/null
exit 0
''';

const _keytool = r'''#!/bin/sh
echo "keytool $*" >> "$STUB_LOG"
exit 0
''';

class ScriptRun {
  ScriptRun(this.exitCode, this.output, this.calls);
  final int exitCode;
  final String output;
  final List<String> calls;
}

/// Runs tools/[script] with [stubs] (a subset of gcloud, gh, keytool) and a
/// secrets directory holding [credentials] when it is non-null.
ScriptRun runScript(
  String script, {
  Set<String> stubs = const {'gcloud', 'gh', 'keytool'},
  String? credentials,
  Map<String, String> env = const {},
}) {
  final dir = Directory.systemTemp.createTempSync('hs-setup');
  try {
    final bin = Directory('${dir.path}/bin')..createSync();
    for (final tool in _utilities) {
      final which = Process.runSync('which', [tool]);
      if (which.exitCode != 0) throw StateError('guard: no $tool');
      Link('${bin.path}/$tool').createSync((which.stdout as String).trim());
    }
    for (final stub in {
      'gcloud': _gcloud,
      'gh': _gh,
      'keytool': _keytool,
    }.entries.where((e) => stubs.contains(e.key))) {
      File('${bin.path}/${stub.key}').writeAsStringSync(stub.value);
      Process.runSync('chmod', ['+x', '${bin.path}/${stub.key}']);
    }
    final secrets = Directory('${dir.path}/secrets')..createSync();
    Process.runSync('chmod', ['700', secrets.path]);
    final keystore = File('${secrets.path}/solitaire-upload.keystore')
      ..writeAsStringSync('not a real keystore');
    if (credentials != null) {
      File(
        '${secrets.path}/solitaire-signing-credentials.txt',
      ).writeAsStringSync(credentials.replaceAll('@KEYSTORE@', keystore.path));
    }
    final log = File('${dir.path}/calls.log')..writeAsStringSync('');
    final r = Process.runSync(
      '${bin.path}/bash',
      ['${repoRoot.path}/tools/$script'],
      includeParentEnvironment: false,
      environment: {
        'PATH': bin.path,
        'HOME': dir.path,
        'HS_SECRETS_DIR': secrets.path,
        'HS_KEYTOOL': '${bin.path}/keytool',
        'STUB_LOG': log.path,
        ...env,
      },
    );
    return ScriptRun(
      r.exitCode,
      '${r.stdout}${r.stderr}',
      log.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
    );
  } finally {
    dir.deleteSync(recursive: true);
  }
}

String creds({String pass = 'same-pass', String keyPass = 'same-pass'}) =>
    '''
export HS_KEYSTORE_PATH="@KEYSTORE@"
export HS_KEYSTORE_PASS="$pass"
export HS_KEY_ALIAS="upload"
export HS_KEY_PASS="$keyPass"
''';

void main() {
  group('setup_play_ci.sh', () {
    test('positive control: the confirmed account gets past the check', () {
      final r = runScript(
        'setup_play_ci.sh',
        env: {'GCLOUD_ACCOUNT': 'owner@x', 'HS_PLAY_ACCOUNT': 'owner@x'},
      );
      expect(r.output, contains('==> project'), reason: r.output);
      expect(r.calls.where((c) => c.startsWith('gh secret set')), isEmpty);
    });

    test('no gcloud is refused with exit 3', () {
      final r = runScript('setup_play_ci.sh', stubs: {'gh'});
      expect([r.exitCode, r.output], [3, contains('gcloud is not on PATH')]);
    });

    test('no active login is refused with exit 4', () {
      final r = runScript('setup_play_ci.sh');
      expect([r.exitCode, r.output], [4, contains('no active gcloud login')]);
    });

    test('a different account than confirmed is refused with exit 4', () {
      final r = runScript(
        'setup_play_ci.sh',
        env: {'GCLOUD_ACCOUNT': 'other@x', 'HS_PLAY_ACCOUNT': 'owner@x'},
      );
      expect(
        [r.exitCode, r.output.contains('Refusing'), r.output.contains('==>')],
        [4, true, false],
        reason:
            'setup-scripts: the wrong gcloud account was not refused\n'
            '${r.output}',
      );
    });

    test('an unconfirmed account with no terminal is refused', () {
      final r = runScript(
        'setup_play_ci.sh',
        env: {'GCLOUD_ACCOUNT': 'owner@x'},
      );
      expect([r.exitCode, r.output], [4, contains('no terminal')]);
    });
  });

  group('set_ci_secrets.sh', () {
    test('positive control: matching credentials set exactly four secrets', () {
      final r = runScript('set_ci_secrets.sh', credentials: creds());
      expect(r.exitCode, 0, reason: r.output);
      expect(r.calls.where((c) => c.startsWith('gh ')).toList(), [
        for (final name in [
          'HS_KEYSTORE_B64',
          'HS_KEYSTORE_PASS',
          'HS_KEY_ALIAS',
          'HS_KEY_PASS',
        ])
          'gh secret set $name -R honestarcade/HonestSolitaire',
      ]);
      expect(r.output, isNot(contains('same-pass')));
    });

    test('a key password that differs is refused before any upload', () {
      final r = runScript(
        'set_ci_secrets.sh',
        credentials: creds(keyPass: 'other-pass'),
      );
      expect(
        [r.exitCode, r.calls.any((c) => c.startsWith('gh '))],
        [2, false],
        reason:
            'setup-scripts: a key-password mismatch was uploaded\n'
            '${r.output}',
      );
    });

    test('a missing field is refused', () {
      final r = runScript(
        'set_ci_secrets.sh',
        credentials: creds().replaceAll(RegExp(r'export HS_KEY_ALIAS.*\n'), ''),
      );
      expect([r.exitCode, r.output], [2, contains('HS_KEY_ALIAS is missing')]);
    });

    test('an unreadable credentials file is refused', () {
      final r = runScript('set_ci_secrets.sh');
      expect([r.exitCode, r.output], [2, contains('cannot read')]);
    });
  });
}
