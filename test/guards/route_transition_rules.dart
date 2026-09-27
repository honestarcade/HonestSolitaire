/// The route-transitions rule (#105): every screen change goes through
/// `FadePageRoute`, so the platform's own transitions, dialogs and sheets
/// never appear in `lib/`. Pure functions, proven on fixtures by the guard.
library;

/// The names whose appearance in code (not comments, not strings) fails.
const bannedRouteSymbols = [
  'MaterialPageRoute',
  'CupertinoPageRoute',
  'showDialog',
  'DialogRoute',
  'showModalBottomSheet',
];

final _banned = RegExp('\\b(${bannedRouteSymbols.join('|')})\\b');

/// Blanks comments and the contents of string literals (keeping their line
/// breaks) so only code is read. Handles `//`, `/* */`, single and triple
/// quotes, raw strings and escapes; interpolations inside a string are
/// treated as string text.
String stripDartCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < source.length) {
    final ch = source[i];
    if (quote != null) {
      if (ch == r'\' && i + 1 < source.length) {
        i += 2;
        continue;
      }
      if (source.startsWith(quote, i)) {
        i += quote.length;
        quote = null;
        continue;
      }
      if (ch == '\n') out.write(ch);
      i++;
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = source.startsWith(ch * 3, i) ? ch * 3 : ch;
      i += quote.length;
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
      for (final c in source.substring(i, stop).split('')) {
        if (c == '\n') out.write(c);
      }
      i = stop;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

/// `<symbol> in <path>:<line>` for every banned name in [source]'s code.
List<String> routeOffenders(String path, String source) {
  final code = stripDartCommentsAndStrings(source);
  final lines = code.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      for (final m in _banned.allMatches(lines[i]))
        '${m.group(1)} in $path:${i + 1}',
  ];
}
