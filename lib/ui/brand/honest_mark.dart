/// The Honest Arcade four-corner mark, from the design's SVG: four stroked
/// corners in teal, violet, blue and deep blue, in a 64-unit box.
library;

import 'package:flutter/rendering.dart';

import '../theme/palette.dart';

class HonestMarkPainter extends CustomPainter {
  const HonestMarkPainter({this.strokeScale = 1.0});

  /// Multiplies the design's stroke width of 8 units.
  final double strokeScale;

  static const _box = 64.0;

  static Path _corner(
    double x0,
    double y0,
    double xMid,
    double yMid,
    double x1,
    double y1,
    bool clockwise,
  ) {
    // M x0 y0 L x0 yMid A 7 7 0 0 sweep xMid y1 L x1 y1
    final p = Path()
      ..moveTo(x0, y0)
      ..lineTo(x0, yMid)
      ..arcToPoint(
        Offset(xMid, y1),
        radius: const Radius.circular(7),
        clockwise: clockwise,
      )
      ..lineTo(x1, y1);
    return p;
  }

  /// The four paths as the design authors them (M/L/A/L, radius 7).
  static final List<(Color, Path)> strokes = [
    (Palette.teal, _corner(11, 25, 18, 18, 25, 11, true)),
    (Palette.violet, _corner(53, 25, 46, 18, 39, 11, false)),
    (Palette.blue, _corner(53, 39, 46, 46, 39, 53, true)),
    (Palette.markDeepBlue, _corner(11, 39, 18, 46, 25, 53, false)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final scale = side / _box;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * strokeScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (color, path) in strokes) {
      paint.color = color;
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HonestMarkPainter oldDelegate) =>
      oldDelegate.strokeScale != strokeScale;
}
