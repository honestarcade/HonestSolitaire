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
// used directly, with structural assertions on the real ci.yml. Grow this
// the way Honest Sudoku's did — one real defect at a time, each with its own
// mutation in tools/mutation_check.py — rather than building the general case
// up front.

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
    test('ci.yml runs on pull requests and can be called by release.yml', () {
      final on = workflow['on'] ?? workflow[true];
      expect(
        on is YamlMap &&
            on.containsKey('pull_request') &&
            on.containsKey('workflow_call'),
        isTrue,
        reason:
            'workflow-structure: ci.yml no longer triggers on '
            'pull_request and workflow_call',
      );
    });

    test('the mutations job runs the battery, not a paraphrase of it', () {
      final jobs = workflow['jobs'] as YamlMap;
      expect(jobs.keys, containsAll(['gate', 'mutations']));
      final runLines = ((jobs['mutations'] as YamlMap)['steps'] as YamlList)
          .whereType<YamlMap>()
          .map((step) => step['run'])
          .whereType<String>()
          .toList();
      expect(
        runLines,
        contains('tools/mutation_check.py'),
        reason:
            'workflow-structure: no step runs tools/mutation_check.py '
            'exactly, so a surviving mutation could leave the check green',
      );
    });

    test('no step in either required job may fail quietly', () {
      final jobs = workflow['jobs'] as YamlMap;
      // A skipped job satisfies a required check (#45), so neither job, nor
      // the step that runs its command, may carry an `if:`.
      const commands = {
        'tools/gate.sh',
        'tools/mutation_check.py',
        'flutter test --no-pub --tags guard',
      };
      final lenient = [
        for (final name in ['gate', 'mutations'])
          if ((jobs[name] as YamlMap)['continue-on-error'] != null ||
              (jobs[name] as YamlMap).containsKey('if'))
            name,
        for (final name in ['gate', 'mutations'])
          for (final step
              in ((jobs[name] as YamlMap)['steps'] as YamlList)
                  .whereType<YamlMap>())
            if (commands.contains(step['run']) && step.containsKey('if'))
              '$name/${step['id'] ?? step['name']}: if',
        for (final name in ['gate', 'mutations'])
          for (final step
              in ((jobs[name] as YamlMap)['steps'] as YamlList)
                  .whereType<YamlMap>())
            if (step['continue-on-error'] != null)
              '$name/${step['id'] ?? step['name']}',
      ];
      expect(
        lenient,
        isEmpty,
        reason: describeOffenders('workflow-skippable', lenient),
      );
    });

    test('every PR bundle is named after the PR head, not the merge ref', () {
      final steps =
          ((workflow['jobs'] as YamlMap)['gate'] as YamlMap)['steps']
              as YamlList;
      final names = [
        for (final s in steps.whereType<YamlMap>())
          if ('${s['uses']}'.startsWith('actions/upload-artifact@'))
            '${(s['with'] as YamlMap?)?['name']}',
      ];
      expect(names, isNotEmpty);
      final wrong = names
          .where(
            (n) => !n.contains(
              r'${{ github.event.pull_request.head.sha || github.sha }}',
            ),
          )
          .toList();
      expect(wrong, isEmpty, reason: describeOffenders('artifact-name', wrong));
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
