/// The playing card, drawn as the design draws it (#72).
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/card.dart';

import '../theme/card_text_styles.dart';
import '../theme/palette.dart';
import 'card_back_painter.dart';
import 'card_labels.dart';
import 'card_style.dart';
import 'suit_paths.dart';

class PlayingCard extends StatelessWidget {
  /// A face-up or face-down card of [size]. [narrow] uses the design's Spider
  /// proportions; [radius] defaults to an eighth of the width.
  const PlayingCard({
    super.key,
    required this.card,
    required this.size,
    required this.back,
    this.ring = CardRing.none,
    this.narrow = false,
    this.radius,
    this.edge = true,
    this.shadow = true,
  });

  /// A back with no card behind it: the Spider stock's slivers.
  const PlayingCard.back(
    Size size,
    CardBack back, {
    Key? key,
    bool edge = true,
    bool shadow = true,
    double? radius,
  }) : this(
         key: key,
         card: null,
         size: size,
         back: back,
         edge: edge,
         shadow: shadow,
         radius: radius,
       );

  /// Null draws a bare back.
  final Card? card;
  final Size size;
  final CardBack back;
  final CardRing ring;
  final bool narrow;

  /// The corner radius; null is an eighth of the width.
  final double? radius;

  double get _radius => radius ?? size.width * 0.125;

  /// The hairline edge around an unringed card.
  final bool edge;
  final bool shadow;

  bool get faceUp => card?.faceUp ?? false;

  /// Width over the design's width for this proportion set.
  double get _scale => size.width / (narrow ? 34 : 48);

  @override
  Widget build(BuildContext context) {
    final c = card;
    final up = c != null && c.faceUp;
    final label = up
        ? '${c.spokenName}${switch (ring) {
            CardRing.selected => ', selected',
            CardRing.hinted => ', hinted',
            CardRing.none => '',
          }}'
        : faceDownLabel;

    final shadows = <BoxShadow>[
      if (ring == CardRing.selected)
        const BoxShadow(color: Palette.selectedRing, spreadRadius: 2)
      else if (ring == CardRing.hinted)
        const BoxShadow(color: Palette.hintRing, spreadRadius: 2)
      else if (edge)
        BoxShadow(
          color: up ? Palette.faceEdge : Palette.backEdge,
          spreadRadius: 1,
        ),
      if (shadow)
        const BoxShadow(
          color: Palette.cardShadow,
          offset: Offset(0, 2),
          blurRadius: 4,
        ),
    ];

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: MediaQuery.withNoTextScaling(
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: up ? Palette.cardFace : back.body,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: shadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: up
                ? _Face(card: c, size: size, narrow: narrow)
                : _Back(back: back, radius: _radius, scale: _scale),
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.back, required this.radius, required this.scale});

  final CardBack back;
  final double radius;
  final double scale;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: CardBackPainter(back, radius: radius, scale: scale),
    size: Size.infinite,
  );
}

class _Face extends StatelessWidget {
  const _Face({required this.card, required this.size, required this.narrow});

  final Card card;
  final Size size;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final rankSize = (w * (narrow ? 0.52 : 0.46)).roundToDouble();
    final suitSize = (rankSize * 0.56).roundToDouble();
    final centerSize = (w * (narrow ? 0.60 : 0.58)).roundToDouble();
    final centerY = (h * (narrow ? 0.40 : 0.38)).roundToDouble();
    final inset = (narrow ? 2.0 : 3.0) * (w / (narrow ? 34 : 48));
    final rankTop = (narrow ? 0.0 : 1.0) * (w / (narrow ? 34 : 48));
    final suitTop = (narrow ? 2.0 : 4.0) * (w / (narrow ? 34 : 48));
    final color = card.isRed ? Palette.redSuit : Palette.blackSuit;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: inset,
          top: rankTop,
          child: Text(
            card.rankName,
            key: const Key('rank'),
            textDirection: TextDirection.ltr,
            style: CardTextStyles.rank(rankSize, color),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _SuitPainter(
              suit: card.suit,
              color: color,
              corner: Rect.fromLTWH(
                w - inset - suitSize,
                suitTop,
                suitSize,
                suitSize,
              ),
              centre: Rect.fromLTWH(
                (w - centerSize) / 2,
                centerY,
                centerSize,
                centerSize,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter({
    required this.suit,
    required this.color,
    required this.corner,
    required this.centre,
  });

  final Suit suit;
  final Color color;
  final Rect corner;
  final Rect centre;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawPath(suitPathAt(suit, corner.topLeft, corner.width), paint);
    canvas.drawPath(suitPathAt(suit, centre.topLeft, centre.width), paint);
  }

  @override
  bool shouldRepaint(_SuitPainter old) =>
      old.suit != suit ||
      old.color != color ||
      old.corner != corner ||
      old.centre != centre;
}
