@Tags(['guard'])
library;

// release.yml's order is its safety property (#36): a tag re-runs the whole
// PR gate, and nothing reaches Play until the bundle has been scanned for
// permissions and matched against the committed upload certificate. Each
// property is read structurally from the parsed workflow.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

/// Every ordering property [releaseYaml] breaks, by name.
List<String> releaseOrderViolations(String releaseYaml) {
  final doc = loadYaml(releaseYaml) as YamlMap;
  final violations = <String>[];
  final on = doc['on'] ?? doc[true];
  final tags = (on is YamlMap && on['push'] is YamlMap)
      ? (on['push'] as YamlMap)['tags']
      : null;
  if (tags is! YamlList || tags.toList().join(',') != 'v*') {
    violations.add('triggers only on v* tags');
  }
  final jobs = doc['jobs'] as YamlMap;
  final gate = jobs['gate'];
  if (gate is! YamlMap || gate['uses'] != './.github/workflows/ci.yml') {
    violations.add('the gate job is ci.yml itself');
  }
  final ship = jobs['ship'];
  if (ship is! YamlMap) return [...violations, 'a ship job exists'];
  final needs = ship['needs'];
  final needed = needs is YamlList ? needs.toList() : [needs];
  if (!needed.contains('gate')) violations.add('ship needs gate');
  final steps = (ship['steps'] as YamlList).whereType<YamlMap>().toList();
  int indexWhere(bool Function(YamlMap) test) => steps.indexWhere(test);
  final scan = indexWhere((s) => s['run'] == 'tools/check_aab.sh');
  final cert = indexWhere((s) => s['run'] == 'tools/verify_upload_cert.sh');
  final play = indexWhere(
    (s) => '${s['uses']}'.startsWith('r0adkll/upload-google-play@'),
  );
  if (play < 0) return [...violations, 'a Play upload step exists'];
  if (scan < 0 || scan > play) {
    violations.add('the permission scan runs before the Play upload');
  }
  if (cert < 0 || cert > play) {
    violations.add('the certificate check runs before the Play upload');
  }
  // A skipped or forgiven job or step satisfies nothing it guards (#45):
  // `if: always()` on ship would ship past a failed gate, and `if: false` or
  // `continue-on-error` on a check would wave its failure through.
  bool lenient(YamlMap node) =>
      node.containsKey('if') || node['continue-on-error'] != null;
  if (lenient(ship)) violations.add('ship runs only when the gate passed');
  for (final (index, what) in [
    (scan, 'the permission scan'),
    (cert, 'the certificate check'),
    (play, 'the Play upload'),
  ]) {
    if (index >= 0 && lenient(steps[index])) {
      violations.add('$what can neither be skipped nor forgiven');
    }
  }
  // The bundle reaches its GitHub release before Play, and the release is
  // created first so the attach never has a reason to skip: a tag pushed
  // without a release would otherwise go green with the bundle attached
  // nowhere and its hash never re-checked.
  final create = indexWhere((s) => s['id'] == 'release');
  final attach = indexWhere((s) => s['id'] == 'asset');
  if (create < 0) {
    violations.add('create step missing');
  } else if (attach >= 0 && create > attach) {
    violations.add('create step after attach');
  }
  if (attach < 0) {
    violations.add('attach step missing');
  } else {
    if (attach > play) violations.add('attach step after the Play upload');
    if (skipsMissingRelease('${steps[attach]['run']}')) {
      violations.add('attach step skips a missing release');
    }
  }
  for (final (index, what) in [(create, 'create'), (attach, 'attach')]) {
    if (index >= 0 && lenient(steps[index])) {
      violations.add('$what step lenient');
    }
  }
  final uploads = steps.where(
    (s) => '${s['uses']}'.startsWith('r0adkll/upload-google-play@'),
  );
  if (uploads.any((s) => (s['with'] as YamlMap?)?['track'] != 'internal')) {
    violations.add('every Play upload targets internal');
  }
  return violations;
}

/// Whether [script] exits successfully from inside an `if … gh release view`
/// block: the shape of an attach that treats a missing release as nothing to
/// do. A bare `exit` counts, since it returns the status of the command before
/// it.
bool skipsMissingRelease(String script) {
  final exits = RegExp(r'(^|[;&|]\s*|\bthen\s+|\belse\s+)exit(\s+0)?\s*($|;)');
  final closes = RegExp(r'(^|;\s*)fi$');
  var depth = 0;
  for (final raw in script.split('\n')) {
    final line = raw.trim();
    if (depth == 0) {
      final at = line.indexOf('gh release view');
      if (!RegExp(r'^(if|elif)\b').hasMatch(line) || at < 0) continue;
      if (exits.hasMatch(line.substring(at))) return true;
      if (!closes.hasMatch(line)) depth = 1;
      continue;
    }
    if (exits.hasMatch(line)) return true;
    if (RegExp(r'^if\b').hasMatch(line) && !closes.hasMatch(line)) depth++;
    if (closes.hasMatch(line) && !RegExp(r'^if\b').hasMatch(line)) depth--;
  }
  return false;
}

void main() {
  const good = '''
on:
  push:
    tags: ['v*']
jobs:
  gate:
    uses: ./.github/workflows/ci.yml
  ship:
    needs: gate
    steps:
      - run: tools/check_aab.sh
      - run: tools/verify_upload_cert.sh
      - id: release
        run: gh release create "\$TAG"
      - id: asset
        run: |
          if ! gh release view "\$TAG"; then
            echo "no release" >&2
            exit 1
          fi
          gh release upload "\$TAG" app.aab
      - uses: r0adkll/upload-google-play@v1
        with:
          track: internal
''';
  const createStep =
      '      - id: release\n'
      '        run: gh release create "\$TAG"\n';
  const attachStep =
      '      - id: asset\n'
      '        run: |\n'
      '          if ! gh release view "\$TAG"; then\n'
      '            echo "no release" >&2\n'
      '            exit 1\n'
      '          fi\n'
      '          gh release upload "\$TAG" app.aab\n';

  group('the rule, proven both ways', () {
    test('the safe order passes', () {
      expect(releaseOrderViolations(good), isEmpty);
    });

    test('each broken property is named', () {
      final broken = good
          .replaceFirst("tags: ['v*']", "tags: ['*']")
          .replaceFirst('    needs: gate\n', '')
          .replaceFirst('      - run: tools/verify_upload_cert.sh\n', '')
          .replaceFirst('track: internal', 'track: production');
      expect(releaseOrderViolations(broken), [
        'triggers only on v* tags',
        'ship needs gate',
        'the certificate check runs before the Play upload',
        'every Play upload targets internal',
      ]);
    });

    test('a skipped or forgiven job or step is caught', () {
      final lenient = good
          .replaceFirst(
            '    needs: gate\n',
            '    needs: gate\n    if: always()\n',
          )
          .replaceFirst(
            '      - run: tools/verify_upload_cert.sh\n',
            '      - run: tools/verify_upload_cert.sh\n'
                '        continue-on-error: true\n',
          )
          .replaceFirst(
            '      - run: tools/check_aab.sh\n',
            '      - run: tools/check_aab.sh\n        if: false\n',
          )
          .replaceFirst(
            '      - uses: r0adkll/upload-google-play@v1\n',
            '      - uses: r0adkll/upload-google-play@v1\n'
                '        if: always()\n',
          );
      expect(releaseOrderViolations(lenient), [
        'ship runs only when the gate passed',
        'the permission scan can neither be skipped nor forgiven',
        'the certificate check can neither be skipped nor forgiven',
        'the Play upload can neither be skipped nor forgiven',
      ]);
    });

    test('a check moved after the upload is caught', () {
      final late =
          '${good.replaceFirst('      - run: tools/check_aab.sh\n', '')}'
          '      - run: tools/check_aab.sh\n';
      expect(releaseOrderViolations(late), [
        'the permission scan runs before the Play upload',
      ]);
    });
  });

  group('the release is created, then attached, then uploaded', () {
    const play = '      - uses: r0adkll/upload-google-play@v1\n';

    test('the fixture holds both steps verbatim', () {
      expect(
        [good.contains(createStep), good.contains(attachStep)],
        [true, true],
      );
    });

    test('a missing create step is caught', () {
      expect(releaseOrderViolations(good.replaceFirst(createStep, '')), [
        'create step missing',
      ]);
    });

    test('a create step after the attach is caught', () {
      final late = good
          .replaceFirst(createStep, '')
          .replaceFirst(play, '$createStep$play');
      expect(releaseOrderViolations(late), ['create step after attach']);
    });

    test('an attach after the Play upload is caught', () {
      final late = '${good.replaceFirst(attachStep, '')}$attachStep';
      expect(releaseOrderViolations(late), [
        'attach step after the Play upload',
      ]);
    });

    test('a skipped or forgiven create or attach step is caught', () {
      final lenient = good
          .replaceFirst(
            '      - id: release\n',
            '      - id: release\n        continue-on-error: true\n',
          )
          .replaceFirst(
            '      - id: asset\n',
            "      - id: asset\n        if: github.event_name == 'push'\n",
          );
      expect(releaseOrderViolations(lenient), [
        'create step lenient',
        'attach step lenient',
      ]);
    });

    test('an attach that skips a missing release is caught', () {
      for (final skip in [
        '            exit 0\n',
        '            exit\n',
        '            [ -n "\$x" ] || exit 0\n',
      ]) {
        final skipping = good.replaceFirst(
          '            exit 1\n',
          '$skip            exit 1\n',
        );
        expect(releaseOrderViolations(skipping), [
          'attach step skips a missing release',
        ], reason: skip);
      }
      expect(
        skipsMissingRelease('if ! gh release view "\$TAG"; then exit 0; fi'),
        isTrue,
      );
    });

    test('an exit 0 outside the release check is not a skip', () {
      expect(
        skipsMissingRelease(
          'if ! gh release view "\$TAG"; then\n  exit 1\nfi\n'
          'if [ -z "\$x" ]; then\n  exit 0\nfi\n',
        ),
        isFalse,
      );
    });
  });

  test('the real release.yml keeps its order', () {
    final violations = releaseOrderViolations(
      readFile('.github/workflows/release.yml'),
    );
    expect(
      violations,
      isEmpty,
      reason: describeOffenders('release-order', violations),
    );
  });
}
