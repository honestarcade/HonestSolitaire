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
      expect(offenders, hasLength(2));
    });

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
      final pubspec = readFile('pubspec.yaml');
      // A minimal top-level-key reader, matching the style of the rule
      // above: pure text, no YAML package required for this small a job. A
      // real project's version of this will likely want `package:yaml` for
      // full structural parsing — see workflow_structure_example_test.dart
      // for that pattern.
      final names = <String>[];
      var inDepsBlock = false;
      for (final line in pubspec.split('\n')) {
        if (RegExp(r'^(dependencies|dev_dependencies):\s*$').hasMatch(line)) {
          inDepsBlock = true;
          continue;
        }
        if (inDepsBlock) {
          if (RegExp(r'^\S').hasMatch(line)) {
            inDepsBlock = false;
            continue;
          }
          final match = RegExp(r'^  ([a-zA-Z0-9_]+):').firstMatch(line);
          if (match != null) names.add(match.group(1)!);
        }
      }
      final offenders = blockedDependencies(names);
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('dependency-policy', offenders),
      );
    });
  });
}
