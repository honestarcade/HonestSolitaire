@Tags(['guard'])
library;

// Every screen change is FadePageRoute's cross-fade (#105): a platform
// route, a dialog or a sheet pasted in from a snippet would bring back the
// platform's own transition. Proven on fixtures, then over lib/.

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';
import 'route_transition_rules.dart';

void main() {
  group('the rules', () {
    test('code is read, comments and strings are not', () {
      const src = '''
// MaterialPageRoute in a comment
/* showDialog in a block
   comment */
final a = 'MaterialPageRoute in a string';
final b = """
DialogRoute in a triple-quoted string
""";
final c = r"showModalBottomSheet in a raw string";
final d = 'escaped \\' CupertinoPageRoute';
Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => x));
final e = MaterialPageRouteX; // a longer name is not the banned one
showDialog<void>(context: context, builder: (_) => y);
''';
      expect(routeOffenders('lib/x.dart', src), [
        'MaterialPageRoute in lib/x.dart:10',
        'showDialog in lib/x.dart:12',
      ]);
    });

    test('a clean file has no offenders', () {
      expect(
        routeOffenders(
          'lib/y.dart',
          'final r = FadePageRoute<void>(builder: (_) => const Menu());',
        ),
        isEmpty,
      );
    });
  });

  test('lib/ pushes nothing but FadePageRoute', () {
    final offenders = [
      for (final path in filesUnder('lib'))
        if (path.endsWith('.dart')) ...routeOffenders(path, readFile(path)),
    ];
    expect(
      offenders,
      isEmpty,
      reason: describeOffenders('route-transitions', offenders),
    );
  });
}
