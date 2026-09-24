@Tags(['guard', 'slow'])
library;

// play-api-check.yml is the proof that CI can reach Play and that the keystore
// secrets are the committed key (#20, #41), so each refusal must be seen to
// fire. The steps' own `run:` bodies are taken from the parsed workflow and
// run under bash with gcloud, curl and keytool stubbed on PATH. Tagged slow:
// every case spawns bash.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

const _gcloud = r'''#!/bin/sh
case "$*" in *print-access-token*) echo stub-token ;; esac
exit 0
''';

const _curl = r'''#!/bin/bash
out=""; method=GET; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w|-H|-d) shift 2 ;;
    -X) method="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$method $url" in
  "POST "*/edits) printf '{"id":"e1"}' > "$out"; printf '%s' "${EDIT_STATUS:-200}" ;;
  *"/tracks") printf '{"tracks":[{"track":"internal"}]}' > "$out"; printf '%s' "${TRACKS_STATUS:-200}" ;;
esac
exit 0
''';

const _keytool = r'''#!/bin/sh
case "$*" in
  *-list*) printf 'Alias name: upload\nSHA256: %s\n' "${SECRET_FP:-AA:BB}" ;;
  *-printcert*) printf 'SHA256: %s\n' "${PEM_FP:-AA:BB}" ;;
esac
exit 0
''';

String stepBody(String id) {
  final doc = loadYaml(readFile('.github/workflows/play-api-check.yml'));
  final steps = ((doc['jobs'] as YamlMap)['check'] as YamlMap)['steps'];
  return (steps as YamlList).whereType<YamlMap>().firstWhere(
        (s) => s['id'] == id,
      )['run']
      as String;
}

class StepRun {
  StepRun(this.exitCode, this.output, this.summary);
  final int exitCode;
  final String output;
  final String summary;
}

StepRun runStep(String id, Map<String, String> env) {
  final dir = Directory.systemTemp.createTempSync('hs-play-check');
  try {
    final bin = Directory('${dir.path}/bin')..createSync();
    for (final stub in {
      'gcloud': _gcloud,
      'curl': _curl,
      'keytool': _keytool,
    }.entries) {
      File('${bin.path}/${stub.key}').writeAsStringSync(stub.value);
      Process.runSync('chmod', ['+x', '${bin.path}/${stub.key}']);
    }
    final summary = File('${dir.path}/summary.md')..writeAsStringSync('');
    final r = Process.runSync(
      'bash',
      ['-c', stepBody(id)],
      workingDirectory: dir.path,
      includeParentEnvironment: false,
      environment: {
        'PATH': '${bin.path}:/usr/bin:/bin',
        'RUNNER_TEMP': dir.path,
        'GITHUB_STEP_SUMMARY': summary.path,
        ...env,
      },
    );
    return StepRun(
      r.exitCode,
      '${r.stdout}${r.stderr}',
      summary.readAsStringSync(),
    );
  } finally {
    dir.deleteSync(recursive: true);
  }
}

const _play = {
  'PLAY_SERVICE_ACCOUNT_JSON': '{"type":"service_account"}',
  'PACKAGE': 'com.honestarcade.solitaire',
};

const _keys = {
  'HS_KEYSTORE_B64': 'eA==',
  'HS_KEYSTORE_PASS': 'same-pass',
  'HS_KEY_ALIAS': 'upload',
  'HS_KEY_PASS': 'same-pass',
};

void main() {
  group('Play access', () {
    test('positive control: an invited account lists the tracks', () {
      final r = runStep('play', _play);
      expect(r.exitCode, 0, reason: r.output);
      expect(r.summary, contains('Tracks: internal'));
    });

    test('a 403 fails the check', () {
      final r = runStep('play', {..._play, 'EDIT_STATUS': '403'});
      expect(
        [r.exitCode, r.output.contains('HTTP 403')],
        [1, true],
        reason: 'play-api-check: a 403 did not fail the check\n${r.output}',
      );
    });

    test('a failed track listing fails the check', () {
      final r = runStep('play', {..._play, 'TRACKS_STATUS': '500'});
      expect(r.exitCode, 1, reason: r.output);
    });

    test('a missing secret fails before any call', () {
      final r = runStep('play', {..._play, 'PLAY_SERVICE_ACCOUNT_JSON': ''});
      expect([r.exitCode, r.output], [1, contains('is not set')]);
    });
  });

  group('Keystore secrets', () {
    test('positive control: matching secrets pass', () {
      final r = runStep('keystore', _keys);
      expect(r.exitCode, 0, reason: r.output);
      expect(r.output, contains('matches the committed certificate'));
    });

    test('a key password that differs from the store password fails', () {
      final r = runStep('keystore', {..._keys, 'HS_KEY_PASS': 'other'});
      expect([r.exitCode, r.output], [1, contains('differs')]);
    });

    test('a keystore that is not the committed key fails', () {
      final r = runStep('keystore', {..._keys, 'SECRET_FP': 'CC:DD'});
      expect(
        [r.exitCode, r.output.contains('NOT the one')],
        [1, true],
        reason: 'play-api-check: a foreign keystore passed\n${r.output}',
      );
    });

    test('a missing secret fails', () {
      final r = runStep('keystore', {..._keys, 'HS_KEY_ALIAS': ''});
      expect([r.exitCode, r.output], [1, contains('HS_KEY_ALIAS is not set')]);
    });
  });
}
