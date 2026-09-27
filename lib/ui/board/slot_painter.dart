/// The empty-slot decorations the design draws: 1 px dashed outlines with
/// per-slot alphas, a 4 % white fill, a suit placeholder at 34 % white and
/// the ↻ recycle arrow — all painted, never glyphs.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:honest_solitaire/engine/card.dart';

import '../card/suit_paths.dart';
import '../theme/palette.dart';

class SlotPainter extends CustomPainter {
  const SlotPainter({
    required this.radius,
    required this.edgeColor,
    this.dashed = true,
    this.fill,
    this.placeholderSuit,
    this.recycle = false,
    this.recycleSize = 14,
  });

  final double radius;
  final Color edgeColor;
  final bool dashed;
  final Color? fill;
  final Suit? placeholderSuit;
  final bool recycle;
  final double recycleSize;

  static const dashLength = 4.0;
  static const gapLength = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = edgeColor;
    if (edgeColor.a > 0) {
      if (dashed) {
        canvas.drawPath(_dash(Path()..addRRect(rrect)), edge);
      } else {
        canvas.drawRRect(rrect, edge);
      }
    }
    if (placeholderSuit != null) {
      final side = size.width * 0.4;
      final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
      canvas.drawPath(
        suitPathAt(placeholderSuit!, origin, side),
        Paint()..color = const Color(0x57FFFFFF),
      );
    }
    if (recycle) _paintRecycle(canvas, size);
  }

  /// One continuous 4/3 dash around the outline, starting where the
  /// top-left corner ends.
  Path _dash(Path source) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = radius * math.pi / 2;
      final start = distance;
      while (distance < metric.length + start) {
        final end = math.min(distance + dashLength, metric.length + start);
        out.addPath(
          metric.extractPath(
            distance % metric.length,
            math.min(end, metric.length),
          ),
          Offset.zero,
        );
        if (end > metric.length) {
          out.addPath(metric.extractPath(0, end - metric.length), Offset.zero);
        }
        distance += dashLength + gapLength;
      }
    }
    return out;
  }

  /// ↻ as an arc with an arrowhead, 14 px tall by default, in the readout
  /// colour.
  void _paintRecycle(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = recycleSize * 0.36;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, recycleSize / 9)
      ..strokeCap = StrokeCap.round
      ..color = Palette.readout;
    final arc = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi * 0.35,
        math.pi * 1.55,
      );
    canvas.drawPath(arc, paint);
    final tip = Offset(
      c.dx + r * math.cos(-math.pi * 0.35),
      c.dy + r * math.sin(-math.pi * 0.35),
    );
    final head = recycleSize * 0.28;
    final arrow = Path()
      ..moveTo(tip.dx - head, tip.dy - head * 0.1)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - head * 0.2, tip.dy + head);
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(SlotPainter old) =>
      old.radius != radius ||
      old.edgeColor != edgeColor ||
      old.dashed != dashed ||
      old.fill != fill ||
      old.placeholderSuit != placeholderSuit ||
      old.recycle != recycle ||
      old.recycleSize != recycleSize;
}
