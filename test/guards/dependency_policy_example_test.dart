@Tags(['guard'])
library;

// Worked example: a dependency-policy-shaped guard.
//
// Honest Sudoku's own version of this rule grew into a ~90-entry blocklist
// (ads, analytics, crash reporting, networking SDKs) checked against 90,000+
// real pub.dev package names to measure false positives — real defect
// history, not a starting point to copy. What's here is the PATTERN: a pure
// function over text (never a live `pub.dev` lookup — guards must run
// offline and fast), an inline fixture so the rule is provable without
// touching the real pubspec.yaml, and the complement asserted explicitly.
//
// The real pubspec.yaml is read too, at the bottom, so this guard does
// something on day one even before you've decided what your own policy is.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'repo_files.dart';

/// Package-name globs this project refuses as direct dependencies.
/// Add to this as your own project's policy — see the header above for why
/// Honest Sudoku's own list is not copied in wholesale.
///
/// `_ads` is anchored on an underscore boundary rather than written as the
/// obvious `*ads*`. Honest Sudoku's own history (issue #97) is the reason:
/// a bare substring match on "ads" also blocks "gamepads", "threads", and
/// "downloads_path_provider" — none of them an advertising SDK. Requiring
/// the underscore is a cheap word boundary that a Dart/pub package name's
/// own naming convention makes reliable.
const blockedNameGlobs = ['*_ads', '*analytics*', '*firebase_crashlytics*'];

bool _matchesGlob(String name, String glob) {
  final pattern = RegExp('^${glob.split('*').map(RegExp.escape).join('.*')}\$');
  return pattern.hasMatch(name);
}

/// Direct-dependency names (the `dependencies:`/`dev_dependencies:` block's
/// own keys, not transitive packages a lockfile would list) that match a
/// blocked glob.
List<String> blockedDependencies(Iterable<String> directDependencyNames) {
  final offenders = <String>[];
  for (final name in directDependencyNames) {
    for (final glob in blockedNameGlobs) {
      if (_matchesGlob(name, glob)) {
        offenders.add('$name (matches $glob)');
        break;
      }
    }
  }
  return offenders;
}

/// Direct dependencies exempt from the justification rule: the SDK itself and
/// the lint set (CLAUDE.md invariant 2).
const justificationExempt = {
  'flutter',
  'flutter_test',
  'flutter_localizations',
  'flutter_lints',
};

/// Every direct dependency named in [pubspec], read structurally (#32): a
/// line scan missed a commented header, deeper indentation, quoted keys and
/// CRLF endings, and each let a blocked package through.
List<String> directDependencies(String pubspec) {
  final doc = loadYaml(pubspec);
  if (doc is! YamlMap) return const [];
  return [
    for (final section in const [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ])
      if (doc[section] is YamlMap)
        for (final key in (doc[section] as YamlMap).keys) '$key',
  ];
}

/// Direct dependencies in [pubspec] whose key line carries no trailing
/// `# why: <reason>` comment. The parser drops comments, so each key's own
/// line is found in the text — quotes and any indentation allowed — and a key
/// whose line cannot be found counts as unjustified.
List<String> unjustifiedDependencies(String pubspec) {
  final text = pubspec.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final offenders = <String>[];
  for (final name in directDependencies(text)) {
    if (justificationExempt.contains(name)) continue;
    final line = RegExp(
      '^[ \\t]+["\']?${RegExp.escape(name)}["\']?[ \\t]*:(.*)\$',
      multiLine: true,
    ).firstMatch(text);
    if (line == null || !RegExp(r'#\s*why:\s*\S').hasMatch(line.group(1)!)) {
      offenders.add(name);
    }
  }
  return offenders;
}

/// pubspec shapes that are valid YAML and used to slip past both rules.
const bypassShapes = {
  'a comment on the header': '''
dependencies: # runtime
  google_mobile_ads: ^5.0.0
''',
  'four-space indentation': '''
dependencies:
    google_mobile_ads: ^5.0.0
''',
  'a quoted key': '''
dependencies:
  "google_mobile_ads": ^5.0.0
''',
  'CRLF line endings': 'dependencies:\r\n  google_mobile_ads: ^5.0.0\r\n',
};

void main() {
  group('the rule itself, proven both ways', () {
    test('an ordinary package is allowed', () {
      expect(
        blockedDependencies(['path', 'shared_preferences', 'collection']),
        isEmpty,
      );
    });

    // The complement: without this, a rule that matches nothing would pass
    // silently forever.
    test('an ads/analytics-shaped package is caught', () {
      final offenders = blockedDependencies([
        'path',
        'google_mobile_ads',
        'firebase_analytics',
      ]);
      expect(offenders, [
        'google_mobile_ads (matches *_ads)',
        'firebase_analytics (matches *analytics*)',
      ]);
      expect(blockedDependencies(['firebase_crashlytics']), hasLength(1));
    });

    for (final shape in bypassShapes.entries) {
      test('${shape.key} does not hide a blocked package', () {
        final names = directDependencies(shape.value);
        expect(blockedDependencies(names), hasLength(1));
        expect(unjustifiedDependencies(shape.value), ['google_mobile_ads']);
      });
    }

    test('an unrelated word containing "ads" is not caught', () {
      // The false-positive class `*_ads`'s underscore boundary exists to
      // avoid: none of these end with the literal segment "_ads", even
      // though "ads" is a substring of each of them.
      expect(
        blockedDependencies(['gamepads', 'threads', 'downloads_path_provider']),
        isEmpty,
      );
    });
  });

  group('this project\'s real pubspec.yaml', () {
    test('declares no blocked dependency', () {
      final names = directDependencies(readFile('pubspec.yaml'));
      expect(names, contains('yaml'), reason: 'the reader found nothing');
      final offenders = blockedDependencies(names);
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('dependency-policy', offenders),
      );
    });
  });

  group('every third-party package explains itself', () {
    test('a package with a reason passes, the SDK needs none', () {
      const pubspec = """
dependencies:
  flutter:
    sdk: flutter
  collection: ^1.19.0 # why: the engine needs ListEquality

dev_dependencies:
  flutter_lints: ^6.0.0
""";
      expect(unjustifiedDependencies(pubspec), isEmpty);
    });

    test('a package without a reason is caught', () {
      const pubspec = """
dependencies:
  collection: ^1.19.0
  path: ^1.9.0 # why:
""";
      expect(unjustifiedDependencies(pubspec), ['collection', 'path']);
    });

    test('the real pubspec.yaml', () {
      final offenders = unjustifiedDependencies(readFile('pubspec.yaml'));
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('missing-why', offenders),
      );
    });
  });
}
