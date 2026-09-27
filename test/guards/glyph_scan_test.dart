@Tags(['guard'])
library;

// Every symbol the design draws as a glyph is a vector icon (#100); a
// string literal under lib/ that carries one would render as a box on a
// phone whose fonts lack it. lib/ui/content/ is prose and exempt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'glyph_rules.dart';
import 'repo_files.dart';

void main() {
  group('the rules', () {
    test('the lexer reads literals and skips comments', () {
      const src = '''
// a comment with ↺
/* and ✕ */
final a = 'plain ✦'; final b = "two ▤"; final c = r'raw ⟳'; final d = \'\'\'
tri ✚
\'\'\';
final e = 'escaped \\' → quote';
''';
      final lits = stringLiterals(src);
      expect(lits.map((l) => l.$2), [
        'plain ✦',
        'two ▤',
        'raw ⟳',
        '\ntri ✚\n',
        "escaped ' → quote",
      ]);
      expect(lits.first.$1, 3);
      expect(lits.last.$1, 6);
    });

    test('a glyph in a literal fails, named; prose and comments do not', () {
      expect(glyphOffenders({'lib/a.dart': "final x = '↺';"}).single, (
        path: 'lib/a.dart',
        line: 1,
        glyph: '↺',
      ));
      expect(glyphOffenders({'lib/a.dart': '// ↺\nfinal x = 1;'}), isEmpty);
      expect(
        glyphOffenders({
          'lib/ui/content/rules_text.dart': "const s = 'a → b';",
        }),
        isEmpty,
      );
      expect(
        glyphOffenders({'lib/a.dart': "final s = 'suits ♠♥';"}),
        isEmpty,
        reason: 'suits are painted elsewhere and allowed in words',
      );
    });
  });

  test('glyph-scan: no text glyph remains under lib/ outside the prose', () {
    final files = {
      for (final path in filesUnder('lib'))
        if (path.endsWith('.dart'))
          path: File('${repoRoot.path}/$path').readAsStringSync(),
    };
    final offenders = glyphOffenders(files);
    expect(
      offenders,
      isEmpty,
      reason:
          'glyph-scan: ${offenders.length} offender(s)\n${offenders.map((o) => '  ${o.path}:${o.line}: ${o.glyph}').join('\n')}',
    );
  });
}
