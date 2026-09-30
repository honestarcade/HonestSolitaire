@Tags(['guard'])
library;

// release.yml's GitHub-release steps, run for real (#169, #175): each
// step's `run:` is read from the workflow and executed by bash against a
// stubbed gh and a scratch repository holding the tags, so what a tag does
// to its release is proven, not read.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

/// The `run:` script of the ship job's step [id] in the real release.yml.
String stepScript(String id) {
  final doc = loadYaml(readFile('.github/workflows/release.yml')) as YamlMap;
  final steps =
      ((doc['jobs'] as YamlMap)['ship'] as YamlMap)['steps'] as YamlList;
  final step = steps.whereType<YamlMap>().firstWhere((s) => s['id'] == id);
  return step['run'] as String;
}

/// A gh that answers the release calls the scripts make, from a state
/// directory: `exists` marks a release, `prerelease` its flag, `body` its
/// notes. Every call is logged, one per line, to `calls`.
const _gh = r'''#!/bin/bash
echo "$*" >> "$STATE/calls"
case "$1 $2" in
  "release view")
    if [ ! -f "$STATE/exists" ]; then echo "release not found" >&2; exit 1; fi
    case "$*" in
      *"--json url"*) echo "https://example.test/$3" ;;
      *"--json isPrerelease"*) [ -f "$STATE/prerelease" ] && echo true || echo false ;;
      *"--json body"*) cat "$STATE/body" 2>/dev/null ;;
    esac ;;
  "release create")
    touch "$STATE/exists"
    case "$*" in *--prerelease*) touch "$STATE/prerelease" ;; esac ;;
  "release edit")
    shift 3
    if [ "$1" = "--notes-file" ]; then cp "$2" "$STATE/body"; fi ;;
  *) echo "stub gh: unexpected $*" >&2; exit 9 ;;
esac
''';

/// Runs step [id] for [tag] in a repository whose history is v0.2.0, then
/// v1.0.0-rc.1, then the commit [tag] names; returns the exit code, the
/// output and the state directory.
Future<(int, String, Directory)> runStep(
  String id,
  String tag, {
  bool exists = false,
  String? body,
}) async {
  final dir = Directory.systemTemp.createTempSync('hs-release');
  addTearDown(() => dir.deleteSync(recursive: true));
  final state = Directory('${dir.path}/state')..createSync();
  final bin = Directory('${dir.path}/bin')..createSync();
  File('${bin.path}/gh').writeAsStringSync(_gh);
  Process.runSync('chmod', ['+x', '${bin.path}/gh']);
  if (exists) File('${state.path}/exists').writeAsStringSync('');
  if (body != null) File('${state.path}/body').writeAsStringSync(body);
  final repo = Directory('${dir.path}/repo')..createSync();
  void git(List<String> args) {
    final r = Process.runSync('git', [
      '-c',
      'user.name=t',
      '-c',
      'user.email=t@t',
      ...args,
    ], workingDirectory: repo.path);
    if (r.exitCode != 0) throw StateError('git ${args.join(' ')}: ${r.stderr}');
  }

  git(['init', '-q']);
  for (final t in ['v0.2.0', 'v1.0.0-rc.1', tag]) {
    git(['commit', '-q', '--allow-empty', '-m', t]);
    git(['tag', t]);
  }
  final script = File('${dir.path}/step.sh')..writeAsStringSync(stepScript(id));
  final r = await Process.run(
    'bash',
    [script.path],
    workingDirectory: repo.path,
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'STATE': state.path,
      'TAG': tag,
      'NAME': '1.0.0',
      'RUN_URL': 'https://example.test/run/1',
      'RUNNER_TEMP': dir.path,
      'GITHUB_OUTPUT': '${dir.path}/output',
    },
  );
  return (r.exitCode, '${r.stdout}${r.stderr}', state);
}

List<String> calls(Directory state) {
  final f = File('${state.path}/calls');
  return f.existsSync() ? f.readAsLinesSync() : const [];
}

void main() {
  group('the create step', () {
    test('an existing release is left untouched', () async {
      final (code, out, state) = await runStep(
        'release',
        'v1.0.0',
        exists: true,
      );
      expect(code, 0, reason: out);
      expect(
        calls(state).where((c) => !c.startsWith('release view')),
        isEmpty,
        reason: 'release-steps: an existing release was created or edited',
      );
    });

    test(
      'a missing final release is created with notes from the last final tag',
      () async {
        final (code, out, state) = await runStep('release', 'v1.0.0');
        expect(code, 0, reason: out);
        final create = calls(state)
            .singleWhere((c) => c.startsWith('release create'));
        expect(create, contains('--verify-tag'));
        expect(create, contains('--generate-notes'));
        expect(
          create,
          contains('--notes-start-tag v0.2.0'),
          reason:
              'release-steps: a final release\'s notes skip the candidates',
        );
        expect(
          create,
          isNot(contains('--prerelease')),
          reason: 'release-steps: a final release was made a prerelease',
        );
        expect(
          File('${state.parent.path}/output').readAsStringSync(),
          contains('prerelease=false'),
        );
      },
    );

    test('a missing candidate is a prerelease, never Latest', () async {
      final (code, out, state) = await runStep('release', 'v1.0.0-rc.2');
      expect(code, 0, reason: out);
      final create = calls(state)
          .singleWhere((c) => c.startsWith('release create'));
      expect(
        create,
        allOf(contains('--prerelease'), contains('--latest=false')),
        reason: 'release-steps: a candidate was not made a prerelease',
      );
      expect(create, contains('--notes-start-tag v1.0.0-rc.1'));
    });
  });

  group('the not-on-Play mark', () {
    const mark = '**This build did not reach Play:**';

    test('a failed run marks the release, once', () async {
      final (code, out, state) = await runStep(
        'mark_release',
        'v1.0.0',
        exists: true,
        body: 'The notes.\n',
      );
      expect(code, 0, reason: out);
      final notes = File('${state.path}/body').readAsStringSync();
      expect(
        notes,
        startsWith(mark),
        reason: 'release-steps: a failed run left no mark',
      );
      expect(notes, contains('The notes.'));
      final (_, _, again) = await runStep(
        'mark_release',
        'v1.0.0',
        exists: true,
        body: notes,
      );
      expect(
        RegExp(RegExp.escape(mark))
            .allMatches(File('${again.path}/body').readAsStringSync()),
        hasLength(1),
        reason: 'release-steps: a second failure stacked a second mark',
      );
    });

    test('a run that reaches Play clears an earlier mark', () async {
      final (code, out, state) = await runStep(
        'clear_release_mark',
        'v1.0.0',
        exists: true,
        body:
            '$mark the release run failed (https://example.test/run/1).\n\nThe notes.\n',
      );
      expect(code, 0, reason: out);
      final notes = File('${state.path}/body').readAsStringSync();
      expect(
        notes,
        isNot(contains(mark)),
        reason: 'release-steps: a run that reached Play left the mark',
      );
      expect(notes, contains('The notes.'));
    });

    test('a release with no mark is not edited', () async {
      final (code, out, state) = await runStep(
        'clear_release_mark',
        'v1.0.0',
        exists: true,
        body: 'The notes.\n',
      );
      expect(code, 0, reason: out);
      expect(
        calls(state).where((c) => c.startsWith('release edit')),
        isEmpty,
        reason: 'release-steps: an unmarked release was edited',
      );
    });
  });
}
