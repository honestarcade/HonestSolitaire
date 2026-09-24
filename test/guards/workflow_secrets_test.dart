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

final _secretExpr = RegExp(r'\$\{\{[^}]*\bsecrets\.');

/// Shell tracing in a `run:` body: `set -x`, `set -o xtrace`, a flag cluster
/// containing x (`set -euxo pipefail`), or `bash -x`/`sh -x`.
final _tracing = RegExp(
  r'(^|[;&|\s])(set\s+(-[a-wyzA-Z]*x[a-zA-Z]*|-o\s+xtrace)|(ba)?sh\s+-[a-wyzA-Z]*x)',
  multiLine: true,
);

/// Every way [workflowYaml] could expose a secret, one line per finding.
List<String> secretExposures(String workflowYaml) {
  final doc = loadYaml(workflowYaml);
  if (doc is! YamlMap) return ['not a YAML mapping'];
  final findings = <String>[];
  bool mentionsSecret(Object? node) => _secretExpr.hasMatch('$node');
  if (mentionsSecret(doc['env'])) findings.add('workflow-level env');
  final jobs = doc['jobs'];
  if (jobs is! YamlMap) return findings;
  for (final entry in jobs.entries) {
    final job = entry.value;
    if (job is! YamlMap) continue;
    if (mentionsSecret(job['env'])) findings.add('${entry.key}: job-level env');
    final steps = job['steps'];
    if (steps is! YamlList) continue;
    for (final step in steps.whereType<YamlMap>()) {
      final id = '${entry.key}/${step['id'] ?? step['name']}';
      final run = step['run'];
      if (run is String) {
        if (_secretExpr.hasMatch(run)) findings.add('$id: secret in run');
        if (_tracing.hasMatch(run)) findings.add('$id: shell tracing');
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
        run: |
          set -euo pipefail
          tools/verify_upload_cert.sh
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
''';
      expect(secretExposures(dirty), [
        'workflow-level env',
        'ship: job-level env',
        'ship/one: secret in run',
        'ship/two: shell tracing',
        'ship/three: shell tracing',
        'ship/four: shell tracing',
        'ship/five: shell tracing',
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
