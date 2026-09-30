@Tags(['guard'])
library;

// The test plan keeps up with the app (#111): every screen route, every
// Settings row and every option value in the code has a place in
// qa/test-plan.md, so a screen or option added later cannot go untested on
// the phone by omission. The run-record template keeps its header fields,
// and every committed record keeps the naming the M6 stories agreed on.
//
// What this does not check: whether an Expected line is right about the app
// (the runs are how that is found out), the steps themselves, or the
// contents of a run record beyond its name.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/navigation.dart';

import 'repo_files.dart';

const planPath = 'qa/test-plan.md';
const templatePath = 'qa/runs/TEMPLATE.md';
const a11yPath = 'qa/a11y-sweep.md';

/// Each route's `##` heading in the plan; the loading screen is both the
/// launch splash and the winnable search, the board both games.
const routeHeadings = <String, List<String>>{
  'menu': ['Menu'],
  'newKlondike': ['New Klondike'],
  'newSpider': ['New Spider'],
  'loading': ['Splash', 'Winnable search'],
  'board': ['Klondike board', 'Spider board'],
  'settings': ['Settings'],
  'stats': ['Statistics'],
  'howToPlay': ['How to play'],
  'aboutApp': ['About the App'],
  'aboutStudio': ['About Honest Arcade'],
};

/// Sections with no route of their own that must still hold checks.
const otherCheckSections = [
  'Pause, win and banner',
  'Gestures',
  'Persistence',
  'Feedback',
];

/// Each `PlaySettings` / `DisplayOptions` field's row label on the Settings
/// screen, which is also its column in the sampling table.
const settingLabels = <String, String>{
  'oneTap': 'One-tap move',
  'autoFinish': 'Auto-finish',
  'autoFlip': 'Auto-flip cards',
  'unlimitedUndo': 'Unlimited undo',
  'winnableOnly': 'Winnable deals only',
  'cardAnimations': 'Card animations',
  'sound': 'Sound effects',
  'music': 'Background music',
  'haptics': 'Haptics',
  'leftHanded': 'Left-handed layout',
  'largeCards': 'Large cards',
  'cardBack': 'Card back',
  'showTimer': 'Show timer',
  'showMovesAndScore': 'Show moves and score',
};

const settingSources = [
  'lib/ui/settings/play_settings.dart',
  'lib/ui/settings/display_options.dart',
];

/// The setup screens' option values as they are displayed, key → (sampling
/// column, values).
const drawValues = ['Draw 1', 'Draw 3'];
const scoringValues = ['Standard', 'Vegas', 'None'];
const suitValues = ['One suit', 'Two suits', 'Four suits'];
const klondikeOnly = <String, (String, List<String>)>{
  'draw': ('Draw', drawValues),
  'scoring': ('Scoring', scoringValues),
  'deal': ('Deal', ['Random deal', 'Winnable only']),
};
const spiderOnly = <String, (String, List<String>)>{
  'suits': ('Suits', suitValues),
  'rule': ('Empty-column rule', ['Strict', 'Relaxed']),
};
const timerValues = ['Timed', 'Untimed'];

/// `YYYY-MM-DD-<device>-<who>[-n].md`.
final runRecordName = RegExp(
  r'^\d{4}-\d{2}-\d{2}-(s26ultra|emu-api24|emu-dev)-(owner|agent)(-\d+)?\.md$',
);

/// The template's header fields and table columns (shared M6 conventions).
const templateFields = [
  'Build',
  'Device',
  'Android / One UI',
  'Hardware or emulator',
  'AVD and image',
  'Runs',
];

final checkHeading = RegExp(r'^### (T\d{3}) — (.+)$');

class Check {
  Check(this.id, this.title, this.lines);

  final String id;
  final String title;
  final List<String> lines;

  bool get retired => title.trimRight().endsWith('(retired)');
}

/// The plan's `##` sections, heading → lines.
Map<String, List<String>> sections(String text) {
  final out = <String, List<String>>{};
  List<String>? current;
  for (final line in text.split('\n')) {
    if (line.startsWith('## ')) {
      current = out[line.substring(3).trim()] = [];
    } else {
      current?.add(line);
    }
  }
  return out;
}

/// The `###` checks in [lines], each with the lines up to the next heading.
List<Check> checksIn(List<String> lines, RegExp heading) {
  final out = <Check>[];
  Check? current;
  for (final line in lines) {
    final m = heading.firstMatch(line);
    if (m != null) {
      current = Check(m[1]!, m[2]!, []);
      out.add(current);
    } else if (line.startsWith('#')) {
      current = null;
    } else {
      current?.lines.add(line);
    }
  }
  return out;
}

List<String> cells(String row) {
  final parts = row.trim().split('|');
  return parts.sublist(1, parts.length - 1).map((c) => c.trim()).toList();
}

/// The sampling table's rows as column → cell.
List<Map<String, String>> samplingRows(List<String> section) {
  final header = section.firstWhere(
    (l) => RegExp(r'^\|\s*Run\s*\|').hasMatch(l),
    orElse: () => '',
  );
  if (header.isEmpty) return [];
  final columns = cells(header);
  return [
    for (final line in section)
      if (RegExp(r'^\|\s*R\d+\s*\|').hasMatch(line))
        {
          for (final (i, cell) in cells(line).indexed)
            if (i < columns.length) columns[i]: cell,
        },
  ];
}

/// Field name → declared type, read from the settings value classes.
Map<String, String> settingFields() => {
  for (final path in settingSources)
    for (final m in RegExp(
      r'^\s*final\s+(\w+)\s+(\w+);',
      multiLine: true,
    ).allMatches(readFile(path)))
      m[2]!: m[1]!,
};

void main() {
  final plan = readFile(planPath);
  final bySection = sections(plan);
  final checks = checksIn(plan.split('\n'), checkHeading);

  test('every AppRoute value has a heading in the plan', () {
    final missing = <String>[];
    for (final route in AppRoute.values) {
      final headings = routeHeadings[route.name];
      if (headings == null) {
        missing.add(
          'test-plan: AppRoute.${route.name} has no entry in the lookup table',
        );
        continue;
      }
      for (final h in headings) {
        if (!bySection.containsKey(h)) {
          missing.add('test-plan: no "## $h" for AppRoute.${route.name}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('every screen, gesture, persistence and feedback section holds a '
      'check', () {
    final empty = <String>[];
    for (final h in [
      ...routeHeadings.values.expand((h) => h),
      ...otherCheckSections,
    ]) {
      final lines = bySection[h];
      if (lines == null || !lines.any((l) => checkHeading.hasMatch(l))) {
        empty.add('test-plan: section "$h" is missing or holds no T-check');
      }
    }
    expect(empty, isEmpty, reason: empty.join('\n'));
  });

  test('every Settings field has its row label in the plan', () {
    final fields = settingFields();
    expect(
      fields,
      isNotEmpty,
      reason: 'test-plan: no fields parsed from the settings sources',
    );
    final screen = readFile('lib/ui/screens/settings_screen.dart');
    final screenLabels = {
      for (final m in RegExp(
        r"SettingRow\(\s*'(\w+)',\s*'([^']+)'",
      ).allMatches(screen))
        m[1]!: m[2]!,
    };
    final settingsText = (bySection['Settings'] ?? const []).join('\n');
    final missing = <String>[];
    for (final field in fields.keys) {
      final label = settingLabels[field];
      if (label == null) {
        missing.add(
          'test-plan: Settings field $field has no label in the table',
        );
        continue;
      }
      final shown = screenLabels[field];
      if (shown != null && shown != label) {
        missing.add(
          'test-plan: $field is "$shown" on the Settings screen, '
          '"$label" in the table',
        );
      }
      if (shown == null && !screen.contains("'$label'")) {
        missing.add(
          'test-plan: "$label" ($field) is not on the Settings screen',
        );
      }
      if (!settingsText.contains(label)) {
        missing.add(
          'test-plan: Settings row "$label" ($field) is not in the Settings section',
        );
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('every option value appears in the sampling table', () {
    // The hand lists follow the engine: a new draw mode, scoring mode or
    // suit count must be added here, and then to the table.
    expect(
      drawValues.length,
      DrawMode.values.length,
      reason: 'test-plan: drawValues is out of step with DrawMode',
    );
    expect(
      scoringValues.length,
      ScoringMode.values.length,
      reason: 'test-plan: scoringValues is out of step with ScoringMode',
    );
    expect(
      suitValues.length,
      SpiderSuits.values.length,
      reason: 'test-plan: suitValues is out of step with SpiderSuits',
    );

    final rows = samplingRows(bySection['Sampling'] ?? const []);
    final missing = <String>[];
    if (rows.isEmpty) missing.add('test-plan: no sampling table rows');

    bool has(Iterable<Map<String, String>> among, String column, String v) =>
        among.any((r) => r[column]?.toLowerCase() == v.toLowerCase());

    void need(
      String key,
      String column,
      List<String> values,
      Iterable<Map<String, String>> among,
    ) {
      if (rows.isNotEmpty && !rows.first.containsKey(column)) {
        missing.add('test-plan: sampling table has no "$column" column');
        return;
      }
      for (final v in values) {
        if (!has(among, column, v)) {
          missing.add('test-plan: sampling table lacks $key=$v');
        }
      }
    }

    final klondike = rows.where((r) => r['Game'] == 'Klondike');
    final spider = rows.where((r) => r['Game'] == 'Spider');
    need('game', 'Game', ['Klondike', 'Spider'], rows);
    klondikeOnly.forEach((k, v) => need(k, v.$1, v.$2, klondike));
    spiderOnly.forEach((k, v) => need(k, v.$1, v.$2, spider));
    need('timer (Klondike)', 'Timer', timerValues, klondike);
    need('timer (Spider)', 'Timer', timerValues, spider);
    need('deal number', 'Deal number', ['blank', 'typed'], rows);
    need('cardBack', 'Card back', [
      for (final b in CardBack.values) b.label,
    ], rows);
    settingFields().forEach((field, type) {
      if (type != 'bool') return;
      final label = settingLabels[field];
      if (label != null) need(field, label, ['on', 'off'], rows);
    });
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('check headings are well-formed and their IDs unique', () {
    final malformed = [
      for (final line in plan.split('\n'))
        if (line.startsWith('### ') && !checkHeading.hasMatch(line))
          'test-plan: malformed check heading "$line"',
    ];
    final seen = <String>{};
    final duplicates = [
      for (final c in checks)
        if (!seen.add(c.id)) 'test-plan: ${c.id} is used twice',
    ];
    expect(checks, isNotEmpty, reason: 'test-plan: no T-checks parsed');
    expect(
      [...malformed, ...duplicates],
      isEmpty,
      reason: [...malformed, ...duplicates].join('\n'),
    );
  });

  test('every live check has an Expected line', () {
    final missing = [
      for (final c in checks)
        if (!c.retired && !c.lines.any((l) => l.startsWith('Expected:')))
          'test-plan: ${c.id} has no Expected:',
    ];
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('every Automated citation names a file that exists', () {
    final missing = <String>[];
    for (final c in checks) {
      for (final line in c.lines) {
        if (!line.startsWith('Automated:')) continue;
        final value = line.substring('Automated:'.length).trim();
        if (value == 'none') continue;
        final path = value.split(' — ').first.trim();
        if (!pathExists(path)) {
          missing.add('test-plan: ${c.id} cites $path, which does not exist');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('the run-record template has its header fields and table', () {
    final template = readFile(templatePath);
    final missing = [
      for (final f in templateFields)
        if (!RegExp(
          '^- ${RegExp.escape(f)}:',
          multiLine: true,
        ).hasMatch(template))
          'test-plan: TEMPLATE.md lacks the header field "$f:"',
      if (!RegExp(
        r'^\|\s*check\s*\|\s*result\s*\|\s*bug\s*\|',
        multiLine: true,
      ).hasMatch(template))
        'test-plan: TEMPLATE.md lacks the check | result | bug table',
    ];
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('the run-record name pattern', () {
    for (final good in [
      '2026-09-29-s26ultra-owner.md',
      '2026-10-01-emu-api24-agent.md',
      '2026-10-01-emu-dev-agent-2.md',
    ]) {
      expect(runRecordName.hasMatch(good), isTrue, reason: good);
    }
    for (final bad in [
      '2026-09-29-s26-owner.md',
      '2026-9-29-s26ultra-owner.md',
      '2026-09-29-s26ultra-claude.md',
      '2026-09-29-s26ultra-owner.txt',
    ]) {
      expect(runRecordName.hasMatch(bad), isFalse, reason: bad);
    }
  });

  test('every committed run record is named by the pattern', () {
    final dir = Directory('${repoRoot.path}/qa/runs');
    expect(dir.existsSync(), isTrue, reason: 'test-plan: qa/runs is missing');
    final misnamed = [
      for (final entry in dir.listSync())
        if (entry is File)
          if (entry.uri.pathSegments.last case final name
              when name != 'TEMPLATE.md' && !runRecordName.hasMatch(name))
            'test-plan: misnamed run record qa/runs/$name',
    ];
    expect(misnamed, isEmpty, reason: misnamed.join('\n'));
  });

  test('every A-check in the accessibility sweep has an Expected line', () {
    final sweep = readFile(a11yPath);
    final aChecks = checksIn(
      sweep.split('\n'),
      RegExp(r'^### (A\d{2}) — (.+)$'),
    );
    expect(aChecks, isNotEmpty, reason: 'test-plan: no A-checks parsed');
    final missing = [
      for (final c in aChecks)
        if (!c.retired && !c.lines.any((l) => l.startsWith('Expected:')))
          'test-plan: ${c.id} in $a11yPath has no Expected:',
    ];
    expect(missing, isEmpty, reason: missing.join('\n'));
  }, skip: pathExists(a11yPath) ? false : '$a11yPath is not written yet');

  test('every A-check cites live T-checks in its Related line', () {
    final sweep = readFile(a11yPath);
    final aChecks = checksIn(
      sweep.split('\n'),
      RegExp(r'^### (A\d{2}) — (.+)$'),
    );
    final live = {
      for (final c in checks)
        if (!c.retired) c.id,
    };
    final wrong = <String>[];
    for (final c in aChecks) {
      if (c.retired) continue;
      final related = c.lines.where((l) => l.startsWith('Related:')).toList();
      final cited = [
        for (final line in related)
          for (final m in RegExp(r'T\d{3}').allMatches(line)) m.group(0)!,
      ];
      if (cited.isEmpty) {
        wrong.add('test-plan: ${c.id} in $a11yPath cites no T-check');
      }
      for (final t in cited) {
        if (!live.contains(t)) {
          wrong.add(
            'test-plan: ${c.id} in $a11yPath cites $t, not a live check',
          );
        }
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });
}
