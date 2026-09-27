/// The win cascade (#104): the foundation cards drop off the bottom of the
/// screen in a gentle waterfall — suit by suit as shown on screen, Kings
/// first — before the win card rises. Presentation only, on one ticker.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';

import 'board_layout.dart';
import 'pile_ref.dart';

/// The last card starts falling at [cascadeSpread]; each fall takes
/// [fallDuration]; the sequence ends at their sum.
const Duration cascadeSpread = Duration(milliseconds: 1600);
const Duration fallDuration = Duration(milliseconds: 400);

/// How long the sequence waits for the win's record before starting.
const Duration recordWait = Duration(seconds: 2);

/// The sideways drift of a falling card at the design width.
const double driftAtDesignWidth = 24;

class FallingCard {
  const FallingCard({
    required this.card,
    required this.from,
    required this.startMs,
    required this.drift,
    required this.order,
    this.narrow = false,
  });

  final Card card;
  final Rect from;
  final int startMs;

  /// Sideways travel by the time the card leaves, in logical pixels.
  final double drift;

  /// Paint order: later cards above earlier ones.
  final int order;
  final bool narrow;

  int get endMs => startMs + fallDuration.inMilliseconds;

  /// Where the card is at [ms]: in place until it starts, then eased down
  /// past [screenHeight] with a linear drift.
  Rect rectAt(int ms, double screenHeight) {
    if (ms <= startMs) return from;
    final t = ((ms - startMs) / fallDuration.inMilliseconds).clamp(0.0, 1.0);
    final dy =
        (screenHeight + from.height - from.top) * Curves.easeIn.transform(t);
    return from.translate(drift * t, dy);
  }

  bool goneAt(int ms) => ms >= endMs;
}

class CascadePlan {
  CascadePlan(this.cards)
    : totalMs = cards.fold(0, (m, c) => math.max(m, c.endMs));

  final List<FallingCard> cards;
  final int totalMs;

  bool get isEmpty => cards.isEmpty;
}

/// The cascade for a won [game] as laid out: Klondike's four foundations in
/// their on-screen order (the left-handed mirror included), King first in
/// each; Spider's completed Kings in slot order at tableau size.
CascadePlan planCascade(
  Game game,
  BoardLayout layout, {
  required double width,
}) {
  final drift = driftAtDesignWidth * width / designWidth;
  final piles = <(Rect, List<Card>, bool)>[];
  switch (game) {
    case KlondikeGame k:
      final order = [
        for (final suit in Suit.values)
          (layout.slots[FoundationPile(suit)]!, k.foundations[suit.index]),
      ]..sort((a, b) => a.$1.left.compareTo(b.$1.left));
      for (final (rect, cards) in order) {
        piles.add((rect, cards.reversed.toList(), false));
      }
    case SpiderGame s:
      final slots = [
        for (var i = 0; i < s.completed.length; i++)
          (i, layout.slots[CompletedPile(i)]!, s.completed[i]),
      ]..sort((a, b) => a.$2.left.compareTo(b.$2.left));
      for (final (_, slot, suit) in slots) {
        final size = layout.cardSize;
        final rect = Rect.fromCenter(
          center: slot.center,
          width: size.width,
          height: size.height,
        );
        piles.add((rect, [Card(kingRank, suit, faceUp: true)], layout.narrow));
      }
  }
  final all = <FallingCard>[];
  var index = 0;
  final count = piles.fold(0, (n, p) => n + p.$2.length);
  final step = count > 1 ? cascadeSpread.inMilliseconds / (count - 1) : 0.0;
  for (var p = 0; p < piles.length; p++) {
    final (rect, cards, narrow) = piles[p];
    final sign = p.isEven ? -1.0 : 1.0;
    for (var i = 0; i < cards.length; i++) {
      all.add(
        FallingCard(
          card: cards[i],
          from: rect,
          startMs: (index * step).round(),
          drift: sign * drift,
          order: index,
          narrow: narrow,
        ),
      );
      index++;
    }
  }
  return CascadePlan(all);
}
