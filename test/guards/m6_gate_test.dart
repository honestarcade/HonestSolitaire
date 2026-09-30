@Tags(['guard'])
library;

// tools/m6_gate.sh (#118) run against a stubbed gh: which open bugs block
// M6's close, and which do not.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final repoRoot = Directory.current;

/// A gh that answers the two API calls the gate makes from fixture files:
/// milestones from STUB_MILESTONES, the milestone's issues from STUB_ISSUES
/// (each file may hold several JSON arrays, as --paginate prints them).
const _gh = r'''#!/bin/bash
case "$*" in
  *milestones*) cat "$STUB_MILESTONES" ;;
  *issues*) cat "$STUB_ISSUES" ;;
  *) echo "stub gh: unexpected $*" >&2; exit 9 ;;
esac
''';

Map<String, Object?> issue(
  int number,
  List<String> labels, {
  String state = 'open',
  bool pr = false,
}) => {
  'number': number,
  'title': 'issue $number',
  'state': state,
  'labels': [
    for (final l in labels) {'name': l},
  ],
  if (pr) 'pull_request': {'url': 'x'},
};

/// Runs the gate with [pages] of issues; returns exit code and output.
(int, String) runGate(List<List<Map<String, Object?>>> pages) {
  final dir = Directory.systemTemp.createTempSync('hs-m6gate');
  try {
    final bin = Directory('${dir.path}/bin')..createSync();
    for (final tool in ['bash', 'jq', 'grep', 'head', 'cat']) {
      final which = Process.runSync('which', [tool]);
      if (which.exitCode != 0) throw StateError('guard: no $tool');
      Link('${bin.path}/$tool').createSync((which.stdout as String).trim());
    }
    File('${bin.path}/gh').writeAsStringSync(_gh);
    Process.runSync('chmod', ['+x', '${bin.path}/gh']);
    final milestones = File('${dir.path}/milestones.json')
      ..writeAsStringSync(
        '${jsonEncode([
          {'number': 5, 'title': 'M5: Earlier'},
        ])}\n${jsonEncode([
          {'number': 7, 'title': 'M6: Testing and bug fixing'},
        ])}\n',
      );
    final issues = File('${dir.path}/issues.json')
      ..writeAsStringSync(pages.map(jsonEncode).join('\n'));
    final r = Process.runSync(
      '${bin.path}/bash',
      ['${repoRoot.path}/tools/m6_gate.sh'],
      includeParentEnvironment: false,
      environment: {
        'PATH': bin.path,
        'STUB_MILESTONES': milestones.path,
        'STUB_ISSUES': issues.path,
      },
    );
    return (r.exitCode, '${r.stdout}${r.stderr}');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  test('no open bug: the gate passes and names the milestone', () {
    final (code, out) = runGate([
      [
        issue(1, ['feature']),
        issue(2, ['bug', 'sev:high'], pr: true),
      ],
    ]);
    expect(
      [code, out],
      [0, contains('no open bug in M6: Testing and bug fixing')],
      reason: 'm6-gate: a story or a pull request blocked the gate',
    );
  });

  test('an open sev:high bug blocks the gate', () {
    final (code, out) = runGate([
      [
        issue(3, ['bug', 'confirmed', 'sev:high']),
      ],
    ]);
    expect(code, 1, reason: 'm6-gate: sev:high bug did not fail the gate');
    expect(
      out,
      contains('BLOCKER #3 sev:high'),
      reason: 'm6-gate: sev:high bug not reported',
    );
  });

  test('critical, unrated and medium/low bugs each block, on every page', () {
    final (code, out) = runGate([
      [
        issue(4, ['bug', 'sev:critical']),
        issue(5, ['bug', 'confirmed']),
      ],
      [
        issue(6, ['bug', 'sev:medium']),
        issue(7, ['bug', 'sev:low', 'area:app']),
      ],
    ]);
    expect(code, 1);
    for (final line in [
      'BLOCKER #4 sev:critical',
      'BLOCKER #5 no severity label',
      'BLOCKER #6 sev:medium still in M6',
      'BLOCKER #7 sev:low still in M6',
    ]) {
      expect(out, contains(line), reason: 'm6-gate: "$line" not reported');
    }
    expect(out, contains('4 blocking bug(s)'));
  });

  test('closed bugs and pull requests do not block', () {
    final (code, out) = runGate([
      [
        issue(8, ['bug', 'sev:critical'], state: 'closed'),
        issue(9, ['bug', 'sev:high'], pr: true),
      ],
    ]);
    expect(
      [code, out],
      [0, isNot(contains('BLOCKER'))],
      reason: 'm6-gate: a closed bug or a pull request blocked the gate',
    );
  });

  test('no M6 milestone is exit 2, not a pass', () {
    final dir = Directory.systemTemp.createTempSync('hs-m6gate-none');
    try {
      final bin = Directory('${dir.path}/bin')..createSync();
      for (final tool in ['bash', 'jq', 'grep', 'head', 'cat']) {
        Link('${bin.path}/$tool').createSync(
          (Process.runSync('which', [tool]).stdout as String).trim(),
        );
      }
      File('${bin.path}/gh').writeAsStringSync(_gh);
      Process.runSync('chmod', ['+x', '${bin.path}/gh']);
      final m = File('${dir.path}/m.json')..writeAsStringSync('[]');
      final r = Process.runSync(
        '${bin.path}/bash',
        ['${repoRoot.path}/tools/m6_gate.sh'],
        includeParentEnvironment: false,
        environment: {
          'PATH': bin.path,
          'STUB_MILESTONES': m.path,
          'STUB_ISSUES': m.path,
        },
      );
      expect(r.exitCode, 2, reason: 'm6-gate: a missing milestone passed');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
