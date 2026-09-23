@Tags(['guard'])
library;

// Worked example: a workflow-structure-shaped guard.
//
// Honest Sudoku's own version of this pattern (workflow_guard_test.dart +
// workflow_yaml.dart) grew into a hand-rolled model of an entire GitHub
// Actions workflow — jobs, steps, `run:` bodies, `permissions:`,
// `concurrency:` — because a text/line-scan version of these same rules was
// defeated repeatedly: a flow-style mapping (`permissions: {contents: read}`),
// a value on the next line, or a quoted scalar all look different in text
// but mean the same thing in YAML. `package:yaml` parses the real structure,
// so the rule sees what the runner sees.
//
// What's here is intentionally smaller: `package:yaml`'s own `loadYaml`,
// used directly, with two structural assertions on the real ci.yml this
// template ships. Grow this the way Honest Sudoku's did — one real defect
// at a time, each with its own mutation in tools/mutation_check.py — rather
// than building the general case up front.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

void main() {
  late YamlMap workflow;

  setUpAll(() {
    final text = readFile('.github/workflows/ci.yml');
    workflow = loadYaml(text) as YamlMap;
  });

  group('the real ci.yml as it stands', () {
    test('the gate job requests read-only contents permission', () {
      final permissions = workflow['permissions'];
      expect(
        permissions,
        isA<YamlMap>(),
        reason: 'workflow-structure: no top-level permissions: block found',
      );
      expect(
        (permissions as YamlMap)['contents'],
        'read',
        reason:
            'workflow-structure: contents permission is not exactly "read" — '
            'a text scan for the literal string "contents: read" would pass '
            'this even if the value were actually "write", because the scan '
            'cannot tell a key from a comment mentioning the same words',
      );
    });

    test('the gate job runs tools/gate.sh, not a paraphrase of it', () {
      final jobs = workflow['jobs'] as YamlMap;
      final gate = jobs['gate'] as YamlMap;
      final steps = gate['steps'] as YamlList;
      final runLines = steps
          .whereType<YamlMap>()
          .map((step) => step['run'])
          .whereType<String>()
          .toList();
      expect(
        runLines,
        contains('tools/gate.sh'),
        reason:
            'workflow-structure: no step runs tools/gate.sh exactly — CI and '
            'a local run must execute the identical command, or "green '
            'locally" and "green in CI" can drift apart',
      );
    });
  });

  group('the rule survives a structural disguise a text scan would miss', () {
    test('a flow-style permissions block is still read correctly', () {
      // The exact shape that defeated a naive line-scan in Honest Sudoku's
      // own history: `permissions: {contents: read}` contains the substring
      // "contents: read" — a `grep`-shaped rule would pass it — but so
      // would `permissions: {contents: write, other: read}`, which a real
      // structural read must NOT pass.
      const flowStyle = '''
permissions: {contents: write, other: read}
jobs:
  x:
    steps: []
''';
      final parsed = loadYaml(flowStyle) as YamlMap;
      final permissions = parsed['permissions'] as YamlMap;
      expect(permissions['contents'], isNot('read'));
    });
  });
}
