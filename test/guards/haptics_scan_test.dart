@Tags(['guard'])
library;

// Every tick goes through lib/feedback/haptics.dart (#107), where the
// Haptics setting is honoured in one place. A HapticFeedback call pasted
// anywhere else — or Flutter's own Feedback helper — would tick with the
// setting off. Comments are stripped; string literals are read too, so the
// channel's method name cannot be invoked by hand either.

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

const allowed = 'lib/feedback/haptics.dart';

final _banned = RegExp(
  r"HapticFeedback\.|Feedback\.for|'HapticFeedback\.vibrate'",
);

/// `<match> in <path>` for every banned use in [source]'s code.
List<String> hapticOffenders(String path, String source) => [
  for (final m in _banned.allMatches(stripDartComments(source)))
    '${m.group(0)} in $path',
];

void main() {
  group('the rules', () {
    test('code is read, comments are not', () {
      const src = '''
// HapticFeedback.lightImpact() in a comment
/* Feedback.forTap in a block */
void undo() { HapticFeedback.lightImpact(); }
final name = 'HapticFeedback.vibrate';
''';
      expect(hapticOffenders('lib/x.dart', src), [
        'HapticFeedback. in lib/x.dart',
        "'HapticFeedback.vibrate' in lib/x.dart",
      ]);
    });
  });

  test('the port exists and ticks with lightImpact', () {
    expect(
      pathExists(allowed),
      isTrue,
      reason: 'haptics-scan: $allowed missing',
    );
    expect(
      readFile(allowed),
      contains('HapticFeedback.lightImpact'),
      reason: 'haptics-scan: $allowed no longer ticks',
    );
  });

  test('nothing outside the port calls HapticFeedback or Feedback', () {
    final offenders = [
      for (final path in trackedFilesUnder('lib'))
        if (path.endsWith('.dart') && path != allowed)
          ...hapticOffenders(path, readFile(path)),
    ];
    expect(
      offenders,
      isEmpty,
      reason: describeOffenders('haptics-scan:', offenders),
    );
  });
}
