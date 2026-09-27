import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/ui/brand/honest_mark.dart';

import '../guards/launcher_icon_rules.dart';
import '../guards/repo_files.dart';

void main() {
  test(
    'HonestMarkPainter draws the studio mark\'s corners at its stroke (#97)',
    () {
      final studio = cornerPaths(readFile('assets/brand/STUDIO-MARK.svg'));
      expect(studio, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(
          HonestMarkPainter.svgPathData(HonestMarkPainter.corners[i]),
          studio[i].$2,
          reason: 'corner ${i + 1} differs from STUDIO-MARK.svg',
        );
      }
      final stroke = RegExp(r'stroke-width="([\d.]+)"')
          .firstMatch(readFile('assets/brand/STUDIO-MARK.svg'))![1]!;
      expect(HonestMarkPainter.strokeWidth, double.parse(stroke));
      expect(
        HonestMarkPainter.strokes.map(
          (s) => s.$1.toARGB32().toRadixString(16).toUpperCase().substring(2),
        ),
        studio.map((c) => c.$1.substring(1)),
      );
    },
  );
}
