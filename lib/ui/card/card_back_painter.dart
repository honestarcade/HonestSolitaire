/// Paints a card back as the design does: an elliptical radial gradient, a
/// 45° hairline pattern, a soft centre glow, two inset strokes and the
/// Honest Arcade mark at 64 % of the width.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../brand/honest_mark.dart';
import '../theme/palette.dart';
import 'card_style.dart';

class CardBackPainter extends CustomPainter {
  const CardBackPainter(this.back, {required this.radius, required this.scale});

  final CardBack back;

  /// The card's corner radius, so the paint stays inside the rounded shape.
  final double radius;

  /// Card width over the design's width (48 for Klondike, 34 for Spider
  /// narrow): the stripe period and glow blur follow it.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rrect, doAntiAlias: true);

    // radial-gradient(78% 68% at 50% 34%, hi 0%, body 52%, lo 100%).
    final gradient = RadialGradient(
      center: const Alignment(0, -0.32),
      radius: 0.78,
      colors: [back.highlight, back.body, back.shade],
      stops: const [0, 0.52, 1],
      transform: _EllipseTransform(0.68 / 0.78 * size.height / size.width),
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // 45° stripes, 1 px every 5 (scaled) from the top-left corner.
    final stripe = Paint()
      ..color = Palette.backStripe
      ..strokeWidth = 1;
    final period = 5 * scale;
    final span = size.width + size.height;
    for (var d = 0.0; d < span; d += period) {
      canvas.drawLine(Offset(d, 0), Offset(0, d), stripe);
    }

    // The centre glow: 62 % × 44 % ellipse, blurred.
    final glow = Paint()
      ..color = Palette.backGlow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: rect.center,
        width: size.width * 0.62,
        height: size.height * 0.44,
      ),
      glow,
    );

    // The two inset strokes (1 px at .14, 3 px at .07).
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Palette.backInsetOuter,
    );
    canvas.drawRRect(
      rrect.deflate(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.backInsetInner,
    );

    // The mark, 64 % of the width, centred.
    final markSide = size.width * 0.64;
    canvas.translate((size.width - markSide) / 2, (size.height - markSide) / 2);
    const HonestMarkPainter().paint(canvas, Size.square(markSide));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CardBackPainter oldDelegate) =>
      oldDelegate.back != back ||
      oldDelegate.radius != radius ||
      oldDelegate.scale != scale;
}

/// Squashes a circular gradient vertically so it reads as the design's
/// 78 % × 68 % ellipse.
class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.yScale);

  final double yScale;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cy = bounds.top + bounds.height * (0.5 - 0.16);
    return Matrix4.identity()
      ..translateByDouble(0, cy, 0, 1)
      ..scaleByDouble(1, math.max(yScale, 0.01), 1, 1)
      ..translateByDouble(0, -cy, 0, 1);
  }
}
