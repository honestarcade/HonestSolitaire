/// The design's symbols as vector icons (#100), so nothing depends on a
/// font glyph: one hand-drawn path per glyph in a 24-unit box with a 3-unit
/// margin, stroked at 1.8/24 of the size with round caps (filled where the
/// design's glyph is solid). Shapes read like the design's Outfit glyphs;
/// none is traced from a font.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum Glyph {
  undo,
  hint,
  finish,
  deal,
  restart,
  newGame,
  back,
  chevron,
  arrow,
  external,
  check,
  close,
  pause,
  recycle;

  /// The solid glyphs: ✦ ✚ ▤ ❚❚.
  bool get filled => switch (this) {
    hint || newGame || deal || pause => true,
    _ => false,
  };
}

const double _box = 24;

/// A round arrow: an arc about the centre with an arrowhead at its start,
/// clockwise ([sweep] > 0) or counter-clockwise.
Path _roundArrow({required double start, required double sweep}) {
  const c = Offset(12, 13);
  const r = 7.5;
  final path = Path()
    ..addArc(Rect.fromCircle(center: c, radius: r), start, sweep);
  final tip = Offset(c.dx + r * math.cos(start), c.dy + r * math.sin(start));
  // The head points along the arc's direction of travel at the tip.
  final dir = sweep > 0 ? start + math.pi / 2 : start - math.pi / 2;
  const head = 4.2;
  Offset at(double angle, double len) =>
      Offset(tip.dx + len * math.cos(angle), tip.dy + len * math.sin(angle));
  path
    ..moveTo(at(dir + math.pi - 0.6, head).dx, at(dir + math.pi - 0.6, head).dy)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(
      at(dir + math.pi + 0.6, head).dx,
      at(dir + math.pi + 0.6, head).dy,
    );
  return path;
}

/// [glyph]'s path in a box of [size] (24 units scaled).
@visibleForTesting
Path glyphPath(Glyph glyph, double size) {
  final p = Path();
  switch (glyph) {
    case Glyph.undo:
      // ↺: counter-clockwise, the head top-left.
      p.addPath(
        _roundArrow(start: -math.pi * 0.62, sweep: -math.pi * 1.55),
        Offset.zero,
      );
    case Glyph.restart:
      // ⟳: clockwise, nearly a full turn.
      p.addPath(
        _roundArrow(start: -math.pi * 0.38, sweep: math.pi * 1.7),
        Offset.zero,
      );
    case Glyph.recycle:
      // ↻: clockwise, as the stock's arrow was painted (#74).
      p.addPath(
        _roundArrow(start: -math.pi * 0.35, sweep: math.pi * 1.55),
        Offset.zero,
      );
    case Glyph.hint:
      // ✦: a four-point star.
      p
        ..moveTo(12, 3)
        ..lineTo(14.6, 9.4)
        ..lineTo(21, 12)
        ..lineTo(14.6, 14.6)
        ..lineTo(12, 21)
        ..lineTo(9.4, 14.6)
        ..lineTo(3, 12)
        ..lineTo(9.4, 9.4)
        ..close();
    case Glyph.finish:
      // ⇈: two chevrons up.
      p
        ..moveTo(6, 11)
        ..lineTo(12, 5)
        ..lineTo(18, 11)
        ..moveTo(6, 19)
        ..lineTo(12, 13)
        ..lineTo(18, 19);
    case Glyph.deal:
      // ▤: three bars.
      for (final y in [4.0, 10.0, 16.0]) {
        p.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(4, y, 16, 4),
            const Radius.circular(1),
          ),
        );
      }
    case Glyph.newGame:
      // ✚: a plus.
      p
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 4, 4, 16),
            const Radius.circular(1),
          ),
        )
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 10, 16, 4),
            const Radius.circular(1),
          ),
        );
    case Glyph.back:
      p
        ..moveTo(16, 4)
        ..lineTo(8, 12)
        ..lineTo(16, 20);
    case Glyph.chevron:
      p
        ..moveTo(8, 4)
        ..lineTo(16, 12)
        ..lineTo(8, 20);
    case Glyph.arrow:
      p
        ..moveTo(4, 12)
        ..lineTo(20, 12)
        ..moveTo(14, 6)
        ..lineTo(20, 12)
        ..lineTo(14, 18);
    case Glyph.external:
      p
        ..moveTo(5, 19)
        ..lineTo(19, 5)
        ..moveTo(9, 5)
        ..lineTo(19, 5)
        ..lineTo(19, 15);
    case Glyph.check:
      p
        ..moveTo(4, 13)
        ..lineTo(10, 19)
        ..lineTo(20, 6);
    case Glyph.close:
      p
        ..moveTo(5, 5)
        ..lineTo(19, 19)
        ..moveTo(19, 5)
        ..lineTo(5, 19);
    case Glyph.pause:
      p
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 3, 6, 18),
            const Radius.circular(1),
          ),
        )
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13, 3, 6, 18),
            const Radius.circular(1),
          ),
        );
  }
  final k = size / _box;
  return p.transform((Matrix4.identity()..scaleByDouble(k, k, 1, 1)).storage);
}

/// Paints [glyph] with its top-left at [origin] in a box of [size].
void paintGlyph(
  Canvas canvas,
  Glyph glyph,
  Offset origin,
  double size,
  Color color,
) {
  final paint = Paint()..color = color;
  if (glyph.filled) {
    paint.style = PaintingStyle.fill;
  } else {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size * 1.8 / _box)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }
  canvas.drawPath(glyphPath(glyph, size).shift(origin), paint);
}

/// One icon, [size] square, in [color] (or the ambient `IconTheme`'s). With
/// [semanticLabel] it is a labelled node; without, it is decorative and
/// excluded, the control beside it carrying the words.
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(
    this.glyph, {
    super.key,
    required this.size,
    this.color,
    this.semanticLabel,
  });

  final Glyph glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(
        glyph,
        color ?? IconTheme.of(context).color ?? Colors.white,
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(label: label, child: paint);
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintGlyph(canvas, glyph, Offset.zero, size.shortestSide, color);

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// An icon inside running text, centred on the line, inheriting its colour
/// and size: "HONEST ARCADE ↗" with the arrow drawn. Middle alignment
/// rather than baseline: a baseline placeholder needs a dry baseline from
/// the painted box, which `RenderCustomPaint` does not provide under
/// `IntrinsicHeight` (the screen scaffold's pinned layout).
InlineSpan inlineGlyph(Glyph glyph, TextStyle style) {
  final size = style.fontSize ?? 14;
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: GlyphIcon(glyph, size: size, color: style.color),
  );
}
