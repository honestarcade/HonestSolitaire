@Tags(['guard'])
library;

// The launcher icon in every form Android asks for, a start screen that is
// navy with the mark, and sources held to the studio's shared mark (#97). The
// rasters are rendered by tools/render_icons.sh and committed; this holds
// their shape, the resources that reference them, the sources, and that the
// template's default icon is gone.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'launcher_icon_rules.dart';
import 'repo_files.dart';

/// A PNG header only: signature and IHDR, which is all the checker reads.
List<int> _png(int w, int h, {int colorType = 6}) {
  final b = ByteData(33);
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    b.setUint8(i, sig[i]);
  }
  b.setUint32(8, 13);
  for (var i = 0; i < 4; i++) {
    b.setUint8(12 + i, 'IHDR'.codeUnitAt(i));
  }
  b.setUint32(16, w);
  b.setUint32(20, h);
  b.setUint8(24, 8);
  b.setUint8(25, colorType);
  return b.buffer.asUint8List();
}

String _describe(String rule, List<String> offenders) =>
    '$rule: ${offenders.length} offender(s)\n  ${offenders.join('\n  ')}';

const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

void main() {
  group('the rules', () {
    test('rasters: right sizes pass; a 100×100 file fails, named', () {
      final good = {
        for (final e in kIconPngs.entries) e.key: _png(e.value, e.value),
      };
      expect(pngOffenders(good), isEmpty);
      const path = '$res/mipmap-hdpi/ic_launcher_foreground.png';
      expect(pngOffenders({...good, path: _png(100, 100)}), [
        '$path: 100×100, not 162×162',
      ]);
      expect(pngOffenders({...good, path: null}), ['$path: missing']);
      expect(pngOffenders({...good, path: _png(162, 162, colorType: 2)}), [
        '$path: colour type 2, not RGBA (6)',
      ]);
      expect(pngHeader([1, 2, 3]), isNull);
    });

    test(
      'the template icon is recognised by its bytes; another file is not',
      () {
        final template = File(
          '${repoRoot.path}/test/fixtures/template_ic_launcher_xxxhdpi.png',
        ).readAsBytesSync();
        expect(
          templateIconOffenders({'xxxhdpi': template}).single,
          contains('template'),
        );
        expect(
          templateIconOffenders({'mdpi': template}),
          isEmpty,
          reason: 'the wrong density: not that file',
        );
        expect(templateIconOffenders({'xxxhdpi': _png(192, 192)}), isEmpty);
        expect(fnv1a64('a'.codeUnits), 0xaf63dc4c8601ec8c);
      },
    );

    test('the adaptive icon needs all three layers', () {
      const full = '''
<adaptive-icon>
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>''';
      expect(adaptiveIconOffenders(full), isEmpty);
      final noMono = full.replaceFirst(RegExp(r'\s*<monochrome[^>]*/>'), '');
      expect(adaptiveIconOffenders(noMono).single, contains('monochrome'));
    });

    test(
      'a corner in another colour fails, named; geometry-only ignores colour',
      () {
        final studio = readFile('assets/brand/STUDIO-MARK.svg');
        final tile = readFile('assets/brand/icon-tile.svg');
        expect(cornerOffenders(tile, studio), isEmpty);
        final violet = tile.replaceFirst('#8448FC', '#FF00FF');
        expect(
          cornerOffenders(violet, studio).single,
          'corner 2 is #FF00FF, not #8448FC',
        );
        expect(cornerOffenders(violet, studio, colours: false), isEmpty);
        final bent = tile.replaceFirst('L 21 3', 'L 22 3');
        expect(
          cornerOffenders(bent, studio).single,
          startsWith('corner 1 is "'),
        );
      },
    );

    test('the splash needs the navy and the mark; the pre-12 background too', () {
      const ok = '''
<style name="LaunchTheme" parent="x">
  <item name="android:windowSplashScreenBackground">@color/launch_navy</item>
  <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>
</style>''';
      expect(splashOffenders(ok), isEmpty);
      expect(
        splashOffenders(ok.replaceFirst('@color/launch_navy', '#FFFFFFFF')),
        hasLength(1),
      );
      expect(
        splashOffenders(
          ok.replaceFirst(
            RegExp(
              r'\s*<item name="android:windowSplashScreenAnimatedIcon">[^\n]*',
            ),
            '',
          ),
        ).single,
        contains('AnimatedIcon'),
      );
      const bg =
          '<item android:drawable="@color/launch_navy" /><item><bitmap android:gravity="center" android:src="@drawable/launch_mark" /></item>';
      expect(launchBackgroundOffenders(bg), isEmpty);
      expect(
        launchBackgroundOffenders(
          '<item android:drawable="@color/launch_navy" />',
        ).single,
        contains('launch_mark'),
      );
    });

    test('the safe-zone reach follows the geometry', () {
      final fg = readFile('assets/brand/android-foreground.svg');
      expect(safeZoneReachDp(fg), closeTo(29.5, 0.2));
      expect(
        safeZoneReachDp(fg.replaceFirst('scale(2.875)', 'scale(3.3)')),
        isNull,
        reason: 'a box no longer centred is not this arithmetic',
      );
    });
  });

  group('the repository', () {
    test('launcher-rasters: every mipmap, the start-screen marks and the store icon, at size, RGBA', () {
      final files = {
        for (final path in kIconPngs.keys)
          path: pathExists(path)
              ? File('${repoRoot.path}/$path').readAsBytesSync()
              : null,
      };
      final offenders = pngOffenders(files);
      expect(
        offenders,
        isEmpty,
        reason: _describe('launcher-rasters', offenders),
      );
    });

    test('launcher-template: the template\'s default icon is gone from every density', () {
      final offenders = templateIconOffenders({
        for (final d in _densities)
          d: File('${repoRoot.path}/$res/mipmap-$d/ic_launcher.png')
              .readAsBytesSync(),
      });
      expect(
        offenders,
        isEmpty,
        reason: _describe('launcher-template', offenders),
      );
    });

    test('launcher-adaptive: background, foreground and monochrome', () {
      final offenders = adaptiveIconOffenders(
        readFile('$res/mipmap-anydpi-v26/ic_launcher.xml'),
      );
      expect(
        offenders,
        isEmpty,
        reason: _describe('launcher-adaptive', offenders),
      );
    });

    test('launcher-splash: Android 12+ shows the mark on navy; earlier the drawable does', () {
      final offenders = [
        for (final dir in ['values-v31', 'values-night-v31'])
          for (final o in splashOffenders(readFile('$res/$dir/styles.xml')))
            '$dir: $o',
        for (final dir in ['drawable', 'drawable-v21'])
          for (final o in launchBackgroundOffenders(
            readFile('$res/$dir/launch_background.xml'),
          ))
            '$dir: $o',
        for (final dir in ['values', 'values-night'])
          if (!readFile('$res/$dir/styles.xml')
              .contains('@drawable/launch_background'))
            '$dir: LaunchTheme does not use @drawable/launch_background',
      ];
      expect(
        offenders,
        isEmpty,
        reason: _describe('launcher-splash', offenders),
      );
    });

    test(
      'launcher-manifest: the icon is @mipmap/ic_launcher, no roundIcon',
      () {
        final manifest = readFile('android/app/src/main/AndroidManifest.xml');
        expect(
          manifest,
          contains('android:icon="@mipmap/ic_launcher"'),
          reason: 'launcher-manifest: the icon is not @mipmap/ic_launcher',
        );
        expect(
          manifest,
          isNot(contains('roundIcon')),
          reason: 'launcher-manifest: roundIcon is set',
        );
      },
    );

    test('launcher-colours: the native navies are the app\'s', () {
      final colors = readFile('$res/values/colors.xml');
      final palette = readFile('lib/ui/theme/palette.dart');
      expect(
        androidColor(colors, 'launch_navy'),
        dartHex(palette, 'navy'),
        reason: 'launcher-colours: launch_navy is not Palette.navy',
      );
      expect(
        androidColor(colors, 'ic_launcher_background'),
        dartHex(palette, 'ink'),
        reason: 'launcher-colours: ic_launcher_background is not Palette.ink',
      );
    });

    test('launcher-mark: the sources carry the studio mark', () {
      final studio = readFile('assets/brand/STUDIO-MARK.svg');
      final offenders = [
        for (final (file, colours) in [
          ('icon-tile.svg', true),
          ('icon-legacy.svg', true),
          ('android-foreground.svg', true),
          ('android-monochrome.svg', false),
        ])
          for (final o in cornerOffenders(
            readFile('assets/brand/$file'),
            studio,
            colours: colours,
          ))
            '$file: $o',
      ];
      expect(offenders, isEmpty, reason: _describe('launcher-mark', offenders));
      expect(
        studio,
        contains('android-foreground-frog-mint.svg'),
        reason: 'launcher-mark: STUDIO-MARK.svg must name the file it was copied from',
      );
    });

    test('launcher-safe-zone: the farthest mark point sits inside the 33-dp radius', () {
      final reach = safeZoneReachDp(
        readFile('assets/brand/android-foreground.svg'),
      );
      expect(
        reach,
        isNotNull,
        reason: 'launcher-safe-zone: the foreground is not a centred 64-unit box with the studio corners',
      );
      expect(
        reach,
        lessThan(33),
        reason:
            'launcher-safe-zone: the mark reaches $reach dp, outside the 33-dp safe radius',
      );
    });

    test('launcher-sources: the inline mark is one copy, the files exist, and nothing here ships', () {
      final marks = {
        for (final f in [
          'icon-tile.svg',
          'icon-legacy.svg',
          'android-foreground.svg',
        ])
          f: inlineMark(readFile('assets/brand/$f')),
      };
      expect(
        marks.values,
        everyElement(isNotNull),
        reason: 'launcher-sources: a source has no mark:begin/mark:end block',
      );
      expect(
        marks.values.toSet(),
        hasLength(1),
        reason: 'launcher-sources: the inline mark copies differ',
      );
      expect(
        filesUnder('assets/brand').map((p) => p.split('/').last).toSet(),
        {
          'icon-tile.svg',
          'icon-legacy.svg',
          'android-foreground.svg',
          'android-monochrome.svg',
          'STUDIO-MARK.svg',
          'README.md',
        },
        reason: 'launcher-sources: unexpected or missing files in assets/brand',
      );
      expect(
        stripYamlComments(readFile('pubspec.yaml')),
        isNot(contains('assets/brand')),
        reason: 'launcher-sources: the brand sources are not app assets',
      );
      final mode = File('${repoRoot.path}/tools/render_icons.sh')
          .statSync()
          .mode;
      expect(
        mode & 0x49,
        isNot(0),
        reason: 'launcher-sources: render_icons.sh is not executable',
      );
    });
  });
}
