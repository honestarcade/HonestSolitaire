/// The four suit symbols as vector paths in a 100×100 box, so Android never
/// renders ♥ or ♦ as colour emoji. The spade follows the brand sheet's.
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:honest_solitaire/engine/card.dart';

Path _heart() {
  final p = Path();
  p.moveTo(50, 92);
  p.cubicTo(38, 80, 4, 60, 4, 32);
  p.cubicTo(4, 16, 16, 6, 29, 6);
  p.cubicTo(39, 6, 47, 13, 50, 21);
  p.cubicTo(53, 13, 61, 6, 71, 6);
  p.cubicTo(84, 6, 96, 16, 96, 32);
  p.cubicTo(96, 60, 62, 80, 50, 92);
  p.close();
  return p;
}

Path _diamond() {
  final p = Path();
  p.moveTo(50, 4);
  p.cubicTo(60, 24, 74, 40, 90, 50);
  p.cubicTo(74, 60, 60, 76, 50, 96);
  p.cubicTo(40, 76, 26, 60, 10, 50);
  p.cubicTo(26, 40, 40, 24, 50, 4);
  p.close();
  return p;
}

Path _spade() {
  final p = Path();
  // The head: an inverted heart.
  p.moveTo(50, 4);
  p.cubicTo(62, 18, 94, 38, 94, 60);
  p.cubicTo(94, 74, 84, 82, 72, 82);
  p.cubicTo(64, 82, 57, 78, 53, 72);
  // The stem, flaring at the base.
  p.cubicTo(54, 82, 58, 90, 66, 96);
  p.lineTo(34, 96);
  p.cubicTo(42, 90, 46, 82, 47, 72);
  p.cubicTo(43, 78, 36, 82, 28, 82);
  p.cubicTo(16, 82, 6, 74, 6, 60);
  p.cubicTo(6, 38, 38, 18, 50, 4);
  p.close();
  return p;
}

Path _club() {
  final p = Path();
  p.addOval(Rect.fromCircle(center: const Offset(50, 26), radius: 22));
  p.addOval(Rect.fromCircle(center: const Offset(27, 60), radius: 22));
  p.addOval(Rect.fromCircle(center: const Offset(73, 60), radius: 22));
  final stem = Path();
  stem.moveTo(53, 60);
  stem.cubicTo(54, 78, 58, 90, 66, 96);
  stem.lineTo(34, 96);
  stem.cubicTo(42, 90, 46, 78, 47, 60);
  stem.close();
  return Path.combine(PathOperation.union, p, stem);
}

final Map<Suit, Path> _paths = {
  Suit.spades: _spade(),
  Suit.hearts: _heart(),
  Suit.diamonds: _diamond(),
  Suit.clubs: _club(),
};

/// The suit's path in its 100-unit box.
Path suitPath(Suit suit) => _paths[suit]!;

/// The suit scaled so its box is [size] wide and tall, with its top-left at
/// [origin]. The symbol fills 90 % of the box, centred horizontally and
/// top-aligned, so it sits where the design's glyph does.
Path suitPathAt(Suit suit, Offset origin, double size) {
  final scale = size * 0.9 / 100;
  final matrix = Matrix4Like.translateScale(
    origin.dx + size * 0.05,
    origin.dy + size * 0.05,
    scale,
  );
  return suitPath(suit).transform(matrix);
}

/// A 4×4 column-major matrix for a translate-then-scale, without pulling in
/// vector_math.
class Matrix4Like {
  const Matrix4Like._();

  static Float64List translateScale(double tx, double ty, double s) {
    final m = Float64List(16);
    m[0] = s;
    m[5] = s;
    m[10] = 1;
    m[12] = tx;
    m[13] = ty;
    m[15] = 1;
    return m;
  }
}
