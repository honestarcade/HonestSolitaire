/// The Honest Arcade four-corner mark: four stroked corners in teal, violet,
/// blue and deep blue in a 64-unit box, with the geometry every studio app
/// shares — `assets/brand/STUDIO-MARK.svg`, held to it by
/// `test/ui/mark_geometry_test.dart` (#97).
library;

import 'package:flutter/rendering.dart';

import '../theme/palette.dart';

/// One corner as the SVG authors it: `M x0 y0 L x0 yMid A r r 0 0 sweep xMid y1
/// L x1 y1`.
typedef CornerSpec = ({
  double x0,
  double y0,
  double xMid,
  double yMid,
  double x1,
  double y1,
  bool clockwise,
});

class HonestMarkPainter extends CustomPainter {
  const HonestMarkPainter({this.strokeScale = 1.0});

  /// Multiplies the mark's stroke width of [strokeWidth] units.
  final double strokeScale;

  static const _box = 64.0;

  /// The studio mark's stroke, in box units.
  static const double strokeWidth = 6;

  /// The corner arcs' radius, in box units.
  static const double cornerRadius = 7;

  /// The four corners, in the SVG's order: top-left, top-right,
  /// bottom-right, bottom-left.
  static const List<CornerSpec> corners = [
    (x0: 3, y0: 21, xMid: 10, yMid: 10, x1: 21, y1: 3, clockwise: true),
    (x0: 61, y0: 21, xMid: 54, yMid: 10, x1: 43, y1: 3, clockwise: false),
    (x0: 61, y0: 43, xMid: 54, yMid: 54, x1: 43, y1: 61, clockwise: true),
    (x0: 3, y0: 43, xMid: 10, yMid: 54, x1: 21, y1: 61, clockwise: false),
  ];

  /// A corner as SVG path data, the way STUDIO-MARK.svg writes it.
  static String svgPathData(CornerSpec c) {
    String n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    final r = n(cornerRadius);
    return 'M ${n(c.x0)} ${n(c.y0)} L ${n(c.x0)} ${n(c.yMid)} '
        'A $r $r 0 0 ${c.clockwise ? 1 : 0} ${n(c.xMid)} ${n(c.y1)} '
        'L ${n(c.x1)} ${n(c.y1)}';
  }

  static Path _corner(CornerSpec c) => Path()
    ..moveTo(c.x0, c.y0)
    ..lineTo(c.x0, c.yMid)
    ..arcToPoint(
      Offset(c.xMid, c.y1),
      radius: const Radius.circular(cornerRadius),
      clockwise: c.clockwise,
    )
    ..lineTo(c.x1, c.y1);

  /// The four paths with their colours, in [corners]' order.
  static final List<(Color, Path)> strokes = [
    (Palette.teal, _corner(corners[0])),
    (Palette.violet, _corner(corners[1])),
    (Palette.blue, _corner(corners[2])),
    (Palette.markDeepBlue, _corner(corners[3])),
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
      ..strokeWidth = strokeWidth * strokeScale
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
