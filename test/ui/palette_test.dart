import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/ui/theme/palette.dart';

void main() {
  test('Palette holds the brand sheet\'s six swatches exactly (#102)', () {
    expect(Palette.brandSwatches, const [
      Color(0xFF00D6B4),
      Color(0xFF0076F1),
      Color(0xFF8448FC),
      Color(0xFF05285F),
      Color(0xFFC6483D),
      Color(0xFFF7F5EF),
    ]);
    expect(Palette.teal, const Color(0xFF00D6B4));
    expect(
      Palette.red,
      const Color(0xFFC6483D),
      reason: 'the brand swatch is untouched',
    );
    expect(
      Palette.redSuit,
      const Color(0xFFC4453A),
      reason: 'the drawn red is the darkened one',
    );
    expect(Palette.disabledOpacity, 0.4);
  });
}
