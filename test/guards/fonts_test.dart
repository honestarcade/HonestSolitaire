@Tags(['guard'])
library;

// The app's two typefaces ship inside it (invariant 1, #96). This holds the
// pubspec declaration, the files, their recorded provenance and every weight
// the code asks for to one another, so a style asking for a weight that is
// not bundled fails here rather than rendering a synthesised face — and no
// code under lib/ names a font host. Ported from Honest Sudoku's guard.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fonts_rules.dart';
import 'repo_files.dart';

String _describe(String rule, List<Offender> offenders) =>
    '$rule: ${offenders.length} offender(s)\n'
    '${offenders.map((o) => '  ${o.path}:${o.line}: ${o.message}').join('\n')}';

const _pubspec = '''
name: x
flutter:
  fonts:
    - family: Outfit
      fonts:
        - asset: assets/fonts/Outfit-Light.ttf
          weight: 300
        - asset: assets/fonts/Outfit-Regular.ttf
          weight: 400
        - asset: assets/fonts/Outfit-Medium.ttf
          weight: 500
        - asset: assets/fonts/Outfit-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Outfit-Bold.ttf
          weight: 700
    - family: IBM Plex Mono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexMono-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
          weight: 600
''';

void main() {
  group('the rules', () {
    test('the declaration: exactly the bundled families and weights', () {
      expect(pubspecFontOffenders(_pubspec), isEmpty);
      final w800 = _pubspec.replaceFirst(
        '          weight: 700\n',
        '          weight: 700\n'
            '        - asset: assets/fonts/Outfit-Bold.ttf\n'
            '          weight: 800\n',
      );
      expect(
        pubspecFontOffenders(w800).single.message,
        contains('"Outfit" declares weights [300, 400, 500, 600, 700, 800]'),
      );
      expect(
        pubspecFontOffenders(
          _pubspec.replaceFirst('family: IBM Plex Mono', 'family: Plex'),
        ),
        hasLength(2),
        reason: 'a renamed family is one missing and one unexpected',
      );
      expect(pubspecFontOffenders('name: x\n'), hasLength(1));
    });

    test('a weight outside the family, or an italic, is refused', () {
      const tokens = '''
const String kFontOutfit = 'Outfit';
const String kFontMono = 'IBM Plex Mono';
class AppFonts {
  static TextStyle outfit(double s, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: kFontOutfit, fontWeight: weight);
  static TextStyle plexMono(double s, {FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: kFontMono, fontWeight: weight);
}
''';
      List<Offender> scan(String code) => weightOffendersIn({
        'lib/ui/fonts.dart': tokens,
        'lib/a.dart': code,
      }, kBundledFonts);

      expect(
        scan('final a = AppFonts.outfit(1, weight: FontWeight.w700);'),
        isEmpty,
      );
      expect(
        scan('final a = AppFonts.plexMono(1, weight: FontWeight.w700);'),
        hasLength(1),
        reason: 'Plex Mono bundles no 700',
      );
      expect(
        scan(
          "final a = TextStyle(fontFamily: kFontMono, fontWeight: FontWeight.bold);",
        ),
        hasLength(1),
      );
      expect(
        scan('final a = TextStyle(fontWeight: FontWeight.w800);'),
        hasLength(1),
        reason: 'no family in the file: the theme font, Outfit',
      );
      expect(
        scan('final a = TextStyle(fontStyle: FontStyle.italic);')
            .single
            .message,
        contains('italic'),
      );
      expect(
        scan("// FontStyle.italic\nfinal a = 'FontWeight.w800';"),
        isEmpty,
        reason: 'comments and strings are not code',
      );
      expect(
        scan(
          "final a = TextStyle(fontFamily: kFontMono, fontWeight: FontWeight.w600);\nfinal b = TextStyle(fontFamily: kFontOutfit, fontWeight: FontWeight.w700);\nfinal c = TextStyle(fontWeight: FontWeight.w700);",
        ),
        isEmpty,
        reason: 'two families named: the bare style is not attributed',
      );
    });

    test('a missing or non-TrueType asset is refused', () {
      final tmp = Directory.systemTemp.createTempSync('fonts_guard');
      addTearDown(() => tmp.deleteSync(recursive: true));
      const one = '''
flutter:
  fonts:
    - family: Outfit
      fonts:
        - asset: a.ttf
''';
      expect(fontAssetOffenders(tmp, one).single.message, contains('missing'));
      File('${tmp.path}/a.ttf').writeAsBytesSync([]);
      expect(fontAssetOffenders(tmp, one).single.message, contains('magic'));
      File('${tmp.path}/a.ttf').writeAsBytesSync([0, 1, 0, 0, 9]);
      expect(fontAssetOffenders(tmp, one), isEmpty);
    });

    test('a font host in code is refused; in a comment it is not', () {
      expect(
        hostOffendersIn({
          'lib/a.dart': "const u = 'https://fonts.googleapis.com/css';",
        }),
        hasLength(1),
      );
      expect(
        hostOffendersIn({
          'lib/a.dart': "const u = 'https://fonts.gstatic.com/s/outfit';",
        }),
        hasLength(1),
      );
      expect(
        hostOffendersIn({
          'lib/a.dart': '// see fonts.googleapis.com\nconst u = 1;',
        }),
        isEmpty,
      );
    });

    test('the provenance records agree', () {
      final h = 'a' * 64;
      final names = [
        'Outfit-Light.ttf',
        'Outfit-Regular.ttf',
        'Outfit-Medium.ttf',
        'Outfit-SemiBold.ttf',
        'Outfit-Bold.ttf',
        'IBMPlexMono-Regular.ttf',
        'IBMPlexMono-Medium.ttf',
        'IBMPlexMono-SemiBold.ttf',
        ...kLicenceFiles,
      ];
      String sums(List<String> ns) => ns.map((n) => '$h  $n\n').join();
      String readme(List<String> ns) =>
          '<!-- fonts:begin -->\n${ns.map((n) => '| `$n` | r | `c` | d | `$h` |\n').join()}<!-- fonts:end -->\n';
      String sources(List<String> ns) =>
          'file\trepo\n${ns.map((n) => '$n\tr\n').join()}';
      List<Offender> check({
        List<String>? s,
        List<String>? r,
        List<String>? t,
      }) => provenanceOffenders(
        readme: readme(r ?? names),
        sums: sums(s ?? names),
        sources: sources(t ?? names),
        pubspecText: _pubspec,
      );
      expect(check(), isEmpty);
      expect(
        check(t: names.sublist(1)).single.message,
        contains('missing [Outfit-Light.ttf]'),
      );
      expect(
        check(
          s: names.sublist(0, 8),
          r: names.sublist(0, 8),
          t: names.sublist(0, 8),
        ),
        hasLength(2),
        reason: 'both licence texts must be recorded',
      );
    });
  });

  group('the repository', () {
    final pubspec = readFile('pubspec.yaml');

    test('fonts-declared: the pubspec declares exactly the bundled fonts', () {
      final offenders = pubspecFontOffenders(pubspec);
      expect(
        offenders,
        isEmpty,
        reason: _describe('fonts-declared', offenders),
      );
    });

    test('fonts-assets: every declared font exists and is TrueType', () {
      final offenders = fontAssetOffenders(repoRoot, pubspec);
      expect(offenders, isEmpty, reason: _describe('fonts-assets', offenders));
    });

    test(
      'fonts-provenance: README, SHA256SUMS, SOURCES.tsv and the pubspec agree',
      () {
        final offenders = provenanceOffenders(
          readme: readFile('assets/fonts/README.md'),
          sums: readFile('assets/fonts/SHA256SUMS'),
          sources: readFile('assets/fonts/SOURCES.tsv'),
          pubspecText: pubspec,
        );
        expect(
          offenders,
          isEmpty,
          reason: _describe('fonts-provenance', offenders),
        );
      },
    );

    test('fonts-weights: every weight lib/ asks of a family is bundled, and nothing is italic', () {
      final bundled = {
        for (final e in declaredFonts(pubspec)!.entries)
          e.key: e.value.keys.toSet(),
      };
      final offenders = weightOffenders(
        Directory('${repoRoot.path}/lib'),
        bundled,
      );
      expect(offenders, isEmpty, reason: _describe('fonts-weights', offenders));
    });

    test('fonts-hosts: nothing under lib/ names a font host', () {
      final offenders = hostOffenders(Directory('${repoRoot.path}/lib'));
      expect(offenders, isEmpty, reason: _describe('fonts-hosts', offenders));
    });

    test(
      'fonts-readme: the README says the fonts are OFL, beside assets/fonts',
      () {
        final readme = readFile('README.md');
        final paragraph = RegExp(r'\*\*Fonts\.\*\*[^\n]*(\n[^\n]+)*')
            .firstMatch(readme)
            ?.group(0);
        expect(
          paragraph,
          isNotNull,
          reason:
              'fonts-readme: no **Fonts.** paragraph in the licence section',
        );
        expect(
          paragraph,
          contains('Open Font License'),
          reason: 'fonts-readme: the paragraph does not name the OFL',
        );
        expect(
          paragraph,
          contains('assets/fonts'),
          reason: 'fonts-readme: the paragraph does not point at assets/fonts',
        );
        expect(
          paragraph,
          isNot(contains('MIT licence, and')),
          reason: 'fonts-readme: the fonts are not MIT',
        );
      },
    );

    test('fonts-check: every file matches its recorded hash', () {
      // bash missing throws, which fails the test: a guard that skips when
      // its tool is absent is no guard.
      final r = Process.runSync('bash', [
        'tools/fetch_fonts.sh',
        '--check',
      ], workingDirectory: repoRoot.path);
      expect(
        r.exitCode,
        0,
        reason:
            'fonts-check: fetch_fonts.sh --check exited ${r.exitCode}\n${r.stdout}${r.stderr}',
      );
    }, tags: ['slow']);
  });
}
