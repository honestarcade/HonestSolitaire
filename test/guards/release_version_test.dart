@Tags(['guard'])
library;

// The version the app shows comes from CI (#86): release.yml must pass
// APP_VERSION and APP_BUILD as --dart-defines taken from its version step's
// outputs, or the Settings screen would read "vdev · BUILD dev" in a store
// build. Proven both ways on inline fixtures, then on the real workflow.
//
// What this does not cover: the PR gate's `HS_APP_BUILD=pr` (a display
// nicety, not a release fact) and the Dart side reading the defines (a unit
// test in test/ui/settings_screen_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

/// The `run:` body of the build step (`id: build`) of the ship job, or null.
String? buildRun(String workflow) {
  final doc = loadYaml(workflow);
  if (doc is! YamlMap) return null;
  final jobs = doc['jobs'];
  if (jobs is! YamlMap) return null;
  for (final job in jobs.values) {
    if (job is! YamlMap) continue;
    final steps = job['steps'];
    if (steps is! YamlList) continue;
    for (final step in steps) {
      if (step is YamlMap && step['id'] == 'build') {
        return step['run']?.toString();
      }
    }
  }
  return null;
}

/// The defines the build passes from the version step, by name.
List<String> passedDefines(String run) => [
  for (final name in ['APP_VERSION', 'APP_BUILD'])
    if (RegExp(
      '--dart-define=$name="?\\\$\\{\\{\\s*steps\\.version\\.outputs\\.(name|code)\\s*\\}\\}"?',
    ).hasMatch(run))
      name,
];

const _good = '''
jobs:
  ship:
    steps:
      - id: version
        run: tools/ci_version.sh
      - id: build
        run: |
          flutter build appbundle --release \\
            --dart-define=APP_VERSION="\${{ steps.version.outputs.name }}" \\
            --dart-define=APP_BUILD="\${{ steps.version.outputs.code }}"
''';

void main() {
  group('the rule, proven both ways', () {
    test('a build passing both defines from the version step passes', () {
      expect(passedDefines(buildRun(_good)!), ['APP_VERSION', 'APP_BUILD']);
    });

    test(
      'a build missing a define, or taking it from elsewhere, is caught',
      () {
        final noBuild = _good.replaceAll(
          '--dart-define=APP_BUILD="\${{ steps.version.outputs.code }}"',
          '',
        );
        expect(passedDefines(buildRun(noBuild)!), ['APP_VERSION']);
        final literal = _good.replaceAll(
          '\${{ steps.version.outputs.name }}',
          '1.0.0',
        );
        expect(passedDefines(buildRun(literal)!), ['APP_BUILD']);
        expect(
          buildRun(
            'jobs:\n  ship:\n    steps:\n      - id: gate\n        run: x\n',
          ),
          isNull,
        );
      },
    );
  });

  test(
    'release.yml passes APP_VERSION and APP_BUILD from its version step',
    () {
      final run = buildRun(readFile('.github/workflows/release.yml'));
      expect(
        run,
        isNotNull,
        reason: 'release-version: release.yml has no step with id: build',
      );
      final passed = passedDefines(run!);
      expect(
        passed,
        contains('APP_VERSION'),
        reason: 'release-version: APP_VERSION is not passed from steps.version.outputs.name',
      );
      expect(
        passed,
        contains('APP_BUILD'),
        reason: 'release-version: APP_BUILD is not passed from steps.version.outputs.code',
      );
    },
  );
}
