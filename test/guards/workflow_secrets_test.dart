@Tags(['guard'])
library;

// No workflow can print a secret (#35). release.yml's header promises two
// things this guard now holds it to: secrets reach steps only through a
// step's own `env:` (or an action's `with:`), never job- or workflow-wide and
// never pasted into a script; and no script turns on shell tracing, which
// would echo every expanded command — keystore password included — into a
// public log.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

/// Any use of the `secrets` context inside an expression — `secrets.X`,
/// `secrets['X']`, `toJSON(secrets)` — not only the dotted form (#46).
final _secretExpr = RegExp(r'\$\{\{[^}]*\bsecrets\b');

/// True when a shell script turns on tracing: any `set` whose options carry
/// an x flag (`set -x`, `set -euxo pipefail`, `set -e -x`) or `xtrace` as the
/// argument of an `o`-ending group (`set -o xtrace`, `set -euo xtrace`), or a
/// shell started with such options (`bash -x`, GitHub's default
/// `bash --noprofile --norc -eo pipefail {0}` with `-x` appended).
bool tracesShell(String script) {
  for (final m in RegExp(
    r'(?:^|[;&|(\s])(?:set|(?:ba|z|k)?sh)((?:[ \t]+[^\s;&|#]+)+)',
    multiLine: true,
  ).allMatches(script)) {
    if (_optionsTrace(m.group(1)!.trim().split(RegExp(r'\s+')))) return true;
  }
  return false;
}

/// Reads [args] as shell options: `--long` options are skipped, a `-` group
/// is checked for x, and a group ending in `o` consumes the next word as its
/// option name. Scanning stops at the first word that is none of these, so `bash tools/run.sh -x` is a script
/// argument, not tracing.
bool _optionsTrace(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (RegExp(r'^--[a-zA-Z][a-zA-Z-]*$').hasMatch(a)) continue;
    if (!RegExp(r'^-[a-zA-Z]+$').hasMatch(a)) return false;
    if (a.contains('x')) return true;
    if (a.endsWith('o') && i + 1 < args.length) {
      if (args[i + 1] == 'xtrace') return true;
      i++;
    }
  }
  return false;
}

/// Every way [workflowYaml] could expose a secret, one line per finding.
List<String> secretExposures(String workflowYaml) {
  final doc = loadYaml(workflowYaml);
  if (doc is! YamlMap) return ['not a YAML mapping'];
  final findings = <String>[];
  bool mentionsSecret(Object? node) => _secretExpr.hasMatch('$node');
  String? defaultShell(Object? owner) {
    if (owner is! YamlMap) return null;
    final defaults = owner['defaults'];
    if (defaults is! YamlMap || defaults['run'] is! YamlMap) return null;
    final shell = (defaults['run'] as YamlMap)['shell'];
    return shell == null ? null : '$shell';
  }

  if (mentionsSecret(doc['env'])) findings.add('workflow-level env');
  final workflowShell = defaultShell(doc);
  if (workflowShell != null && tracesShell(workflowShell)) {
    findings.add('workflow default shell traces');
  }
  final jobs = doc['jobs'];
  if (jobs is! YamlMap) return findings;
  for (final entry in jobs.entries) {
    final job = entry.value;
    if (job is! YamlMap) continue;
    if (mentionsSecret(job['env'])) findings.add('${entry.key}: job-level env');
    final jobShell = defaultShell(job);
    if (jobShell != null && tracesShell(jobShell)) {
      findings.add('${entry.key}: default shell traces');
    }
    final steps = job['steps'];
    if (steps is! YamlList) continue;
    for (final step in steps.whereType<YamlMap>()) {
      final id = '${entry.key}/${step['id'] ?? step['name']}';
      final run = step['run'];
      if (run is String) {
        if (_secretExpr.hasMatch(run)) findings.add('$id: secret in run');
        if (tracesShell(run)) findings.add('$id: shell tracing');
      }
      final shell = step['shell'];
      if (shell != null && tracesShell('$shell')) {
        findings.add('$id: shell traces');
      }
    }
  }
  return findings;
}

void main() {
  group('the rule, proven both ways', () {
    const clean = r'''
jobs:
  ship:
    steps:
      - id: keystore
        env:
          PASS: ${{ secrets.PASS }}
        shell: bash --noprofile --norc -eo pipefail {0}
        run: |
          set -euo pipefail
          set +x
          tools/verify_upload_cert.sh --exit-code
          bash tools/run.sh -x
          set -o pipefail
''';

    test('secrets in step env with no tracing pass', () {
      expect(secretExposures(clean), isEmpty);
    });

    test('every exposure shape is caught', () {
      const dirty = r'''
env:
  A: ${{ secrets.A }}
jobs:
  ship:
    env:
      B: ${{ secrets.B }}
    steps:
      - id: one
        run: echo "${{ secrets.C }}"
      - id: two
        run: |
          set -x
      - id: three
        run: set -euxo pipefail
      - id: four
        run: bash -x tools/thing.sh
      - id: five
        run: |
          true
          set -o xtrace
      - id: six
        run: set -e -x
      - id: seven
        run: set -eu -o xtrace
      - id: eight
        shell: bash -x {0}
        run: echo hi
      - id: nine
        run: echo '${{ toJSON(secrets) }}'
      - id: ten
        run: echo "${{ secrets['X'] }}"
      - id: eleven
        shell: bash --noprofile --norc -eo pipefail -x {0}
        run: echo hi
      - id: twelve
        run: set -euo xtrace
  other:
    defaults:
      run:
        shell: bash -eux {0}
    steps: []
''';
      expect(secretExposures(dirty), [
        'workflow-level env',
        'ship: job-level env',
        'ship/one: secret in run',
        'ship/two: shell tracing',
        'ship/three: shell tracing',
        'ship/four: shell tracing',
        'ship/five: shell tracing',
        'ship/six: shell tracing',
        'ship/seven: shell tracing',
        'ship/eight: shell traces',
        'ship/nine: secret in run',
        'ship/ten: secret in run',
        'ship/eleven: shell traces',
        'ship/twelve: shell tracing',
        'other: default shell traces',
      ]);
      expect(secretExposures('defaults:\n  run:\n    shell: bash -x {0}\n'), [
        'workflow default shell traces',
      ]);
    });
  });

  test('no workflow can print a secret', () {
    final workflows = trackedFilesUnder('.github/workflows');
    expect(workflows, contains('.github/workflows/release.yml'));
    final findings = [
      for (final path in workflows)
        for (final f in secretExposures(readFile(path))) '$path: $f',
    ];
    expect(
      findings,
      isEmpty,
      reason: describeOffenders('workflow-secret-exposure', findings),
    );
  });
}
