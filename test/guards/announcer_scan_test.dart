@Tags(['guard'])
library;

// Every spoken announcement goes through lib/ui/a11y/announcer.dart (#108),
// which speaks only while a screen reader is on and lets tests read what
// was said. A SemanticsService call pasted anywhere else would speak to
// nobody in tests and to everybody in the app.

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

const allowed = 'lib/ui/a11y/announcer.dart';

final _banned = RegExp(r'SemanticsService\.');

/// `<match> in <path>` for every use in [source]'s code.
List<String> announcerOffenders(String path, String source) => [
  for (final m in _banned.allMatches(stripDartComments(source)))
    '${m.group(0)} in $path',
];

void main() {
  test('the rules read code, not comments', () {
    const src = '''
// SemanticsService.sendAnnouncement in a comment
void say() { SemanticsService.sendAnnouncement(view, 'x', dir); }
''';
    expect(announcerOffenders('lib/x.dart', src), [
      'SemanticsService. in lib/x.dart',
    ]);
  });

  test('the announcer exists and speaks through SemanticsService', () {
    expect(
      pathExists(allowed),
      isTrue,
      reason: 'announcer-scan: $allowed missing',
    );
    expect(
      readFile(allowed),
      contains('SemanticsService.sendAnnouncement'),
      reason: 'announcer-scan: $allowed no longer speaks',
    );
  });

  test('nothing outside the announcer calls SemanticsService', () {
    final offenders = [
      for (final path in trackedFilesUnder('lib'))
        if (path.endsWith('.dart') && path != allowed)
          ...announcerOffenders(path, readFile(path)),
    ];
    expect(
      offenders,
      isEmpty,
      reason: describeOffenders('announcer-scan:', offenders),
    );
  });
}
