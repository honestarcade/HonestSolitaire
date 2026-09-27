// The glyph-scan rule (#100): string literals under lib/ may not carry the
// symbols the icon set draws. A small lexer, because a regex over source
// cannot tell a comment from a literal.
library;

/// The symbols `GlyphIcon` draws; none may remain as text.
const String kGlyphs = '↺✦⇈▤⟳✚‹›→↗✓✕❚↻';

/// Directories whose literals are prose (copy that may say "→" in a
/// sentence), skipped by the scan.
const List<String> kProseDirs = ['lib/ui/content/'];

typedef Offender = ({String path, int line, String glyph});

/// Every string literal in Dart [source] with its 1-based start line:
/// single, double, raw and triple-quoted, with `//` and `/* */` comments
/// skipped. Interpolations are read as part of the literal (their text
/// is scanned too, which errs towards finding a glyph).
List<(int, String)> stringLiterals(String source) {
  final out = <(int, String)>[];
  var i = 0;
  var line = 1;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '\n') {
      line++;
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      final stop = end < 0 ? source.length : end + 2;
      line += '\n'.allMatches(source.substring(i, stop)).length;
      i = stop;
      continue;
    }
    final raw =
        ch == 'r' &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"');
    if (raw || ch == "'" || ch == '"') {
      final start = raw ? i + 1 : i;
      final q = source[start];
      final quote = source.startsWith(q * 3, start) ? q * 3 : q;
      var j = start + quote.length;
      final startLine = line;
      final buf = StringBuffer();
      while (j < source.length && !source.startsWith(quote, j)) {
        if (!raw && source[j] == r'\' && j + 1 < source.length) {
          buf.write(source[j + 1]);
          j += 2;
          continue;
        }
        if (source[j] == '\n') line++;
        buf.write(source[j]);
        j++;
      }
      out.add((startLine, buf.toString()));
      i = j + quote.length;
      continue;
    }
    i++;
  }
  return out;
}

/// Every glyph in a literal of [files] (path → source) outside [kProseDirs].
///
/// Not covered, by design: a glyph built from a code point or a `\u` escape
/// (`String.fromCharCode(0x21BA)`, `'↺'`), which no honest edit types.
List<Offender> glyphOffenders(Map<String, String> files) => [
  for (final e in files.entries)
    if (!kProseDirs.any((d) => e.key.startsWith(d)))
      for (final (line, text) in stringLiterals(e.value))
        for (final g in kGlyphs.runes.map(String.fromCharCode))
          if (text.contains(g)) (path: e.key, line: line, glyph: g),
];
