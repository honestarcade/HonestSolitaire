@Tags(['guard'])
library;

// Every text and graphic colour Palette declares reaches WCAG AA on each
// surface it sits on (#102), and every nudged token is the nearest passing
// shade of its design value, re-derived here so a hand edit cannot drift.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/ui/theme/contrast.dart';
import 'package:honest_solitaire/ui/theme/palette.dart';

String _hex(Color c) =>
    '#${rounded(c).toARGB32().toRadixString(16).substring(2).toUpperCase()}';

void main() {
  test('the arithmetic: known ratios', () {
    expect(
      contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF16202B), const Color(0xFFF7F5EF)),
      greaterThan(13),
    );
    expect(
      contrastRatio(Palette.red, Palette.cardFace),
      closeTo(4.38, 0.02),
      reason: 'the design red, as measured',
    );
    expect(
      composite(const Color(0x80FFFFFF), const Color(0xFF000000)),
      rounded(const Color(0xFF808080)),
    );
    expect(
      nudge(const Color(0xFF5C7FB0), [Palette.navy]).steps,
      greaterThan(0),
    );
  });

  test('every declared pair passes on every surface', () {
    final failures = <String>[];
    for (final pair in Palette.textPairs) {
      if (pair.disabled) continue;
      final target = pair.large || pair.graphic
          ? kLargeTextContrast
          : kTextContrast;
      for (final surface in pair.surfaces) {
        final fg = composite(pair.fg, surface);
        final ratio = contrastRatio(fg, surface);
        if (ratio < target) {
          failures.add(
            '${pair.name}: ${_hex(fg)} on ${_hex(surface)} is ${ratio.toStringAsFixed(2)}:1, below $target:1',
          );
        }
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          'contrast: ${failures.length} pair(s) fail\n  ${failures.join('\n  ')}',
    );
  });

  test('every nudged token is the nearest passing shade of its design value', () {
    final drift = <String>[];
    for (final n in Palette.nudges) {
      final want = nudge(n.design, n.surfaces).color;
      if (rounded(n.token) != want) {
        drift.add(
          '${n.name} is ${_hex(n.token)}; the nearest passing shade of ${_hex(n.design)} is ${_hex(want)}',
        );
      }
    }
    expect(
      drift,
      isEmpty,
      reason:
          'contrast: ${drift.length} token(s) drifted\n  ${drift.join('\n  ')}',
    );
  });
}
