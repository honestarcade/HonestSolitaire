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

// One argument per line, so an argument holding a space stays one argument
// and the exact argv can be compared.
const _keytool = r'''#!/bin/sh
{
  echo "== call"
  for a in "$@"; do printf '%s\n' "$a"; done
  [ -n "${HS_PASS_PROBE+set}" ] && printf '== env HS_PASS_PROBE=%s\n' "$HS_PASS_PROBE"
} >> "$KEYTOOL_LOG"
case "$*" in *-help*) echo "Key and Certificate Management Tool"; exit 0 ;; esac
[ -n "${KEYTOOL_FAIL:-}" ] && exit 1
exit 0
''';

class KeytoolCall {
  KeytoolCall(this.argv, this.passProbe);
  final List<String> argv;

  /// `HS_PASS_PROBE` as keytool saw it, or null when it was not set.
  final String? passProbe;
}

class ScriptRun {
  ScriptRun(
    this.exitCode,
    this.output,
    this.calls,
    this.keytool,
    this.keystore,
  );
  final int exitCode;
  final String output;
  final List<String> calls;
  final List<KeytoolCall> keytool;
  final String keystore;
}

List<KeytoolCall> _keytoolCalls(List<String> lines) {
  final calls = <KeytoolCall>[];
  List<String>? argv;
  String? probe;
  void flush() {
    if (argv != null) calls.add(KeytoolCall(argv, probe));
  }

  for (final line in lines) {
    if (line == '== call') {
      flush();
      argv = [];
      probe = null;
    } else if (line.startsWith('== env HS_PASS_PROBE=')) {
      probe = line.substring('== env HS_PASS_PROBE='.length);
    } else {
      argv?.add(line);
    }
  }
  flush();
  return calls;
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
    final keytoolLog = File('${dir.path}/keytool.log')..writeAsStringSync('');
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
        'KEYTOOL_LOG': keytoolLog.path,
        ...env,
      },
    );
    return ScriptRun(
      r.exitCode,
      '${r.stdout}${r.stderr}',
      log.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
      _keytoolCalls(keytoolLog.readAsLinesSync()),
      keystore.path,
    );
  } finally {
    dir.deleteSync(recursive: true);
  }
}

String creds({String pass = 'same-pass', String keyPass = 'same-pass'}) =>
    '''
export HS_KEYSTORE_PATH="@KEYSTORE@"
export HS_KEYSTORE_PASS="$pass"
export HS_KEY_ALIAS="upload key"
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

    test('the pre-flight asks keytool for the alias, password by env', () {
      final r = runScript('set_ci_secrets.sh', credentials: creds());
      expect(r.exitCode, 0, reason: r.output);
      final argvs = [for (final c in r.keytool) c.argv];
      expect(
        argvs.where((a) => a.any((w) => w.contains('same-pass'))),
        isEmpty,
        reason:
            "setup-scripts: the keystore password is on keytool's command "
            'line\n$argvs',
      );
      final list = r.keytool.where((c) => c.argv.contains('-list')).toList();
      expect(list, hasLength(1), reason: 'setup-scripts: no keytool -list');
      final argv = list.single.argv;
      final alias = argv.indexOf('-alias');
      expect(
        alias >= 0 && alias + 1 < argv.length ? argv[alias + 1] : null,
        'upload key',
        reason: 'setup-scripts: keytool -list does not check the alias\n$argv',
      );
      expect(
        list.single.passProbe,
        'same-pass',
        reason:
            'setup-scripts: keytool -list did not get the password in '
            'HS_PASS_PROBE',
      );
      expect(argv, [
        '-list',
        '-keystore',
        r.keystore,
        '-storetype',
        'PKCS12',
        '-storepass:env',
        'HS_PASS_PROBE',
        '-alias',
        'upload key',
      ], reason: 'setup-scripts: keytool -list argv drifted');
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

    test('a password that does not open the keystore is refused', () {
      final r = runScript(
        'set_ci_secrets.sh',
        credentials: creds(),
        env: {'KEYTOOL_FAIL': '1'},
      );
      expect(
        [r.exitCode, r.calls.any((c) => c.startsWith('gh '))],
        [2, false],
        reason:
            'setup-scripts: a keystore the password cannot open was '
            'uploaded\n${r.output}',
      );
      expect(r.output, contains('do not open the keystore'));
    });

    test('a keystore path that cannot be read is refused', () {
      final r = runScript(
        'set_ci_secrets.sh',
        credentials: creds().replaceAll('@KEYSTORE@', '/nonexistent/k.p12'),
      );
      expect(
        [r.exitCode, r.calls.where((c) => c.startsWith('gh ')).toList()],
        [2, isEmpty],
        reason:
            'setup-scripts: an unreadable keystore reached gh\n'
            '${r.output}',
      );
      expect(r.output, contains('is not readable'));
    });

    test('an unreadable credentials file is refused', () {
      final r = runScript('set_ci_secrets.sh');
      expect([r.exitCode, r.output], [2, contains('cannot read')]);
    });
  });
}
