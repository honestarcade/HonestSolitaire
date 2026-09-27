/// The deal, animated (#103): a new game's cards leave the stock and land
/// in their columns, column by column, the last landing at [dealDuration];
/// the top cards flip after landing. Built as a #99 motion plan, so the
/// board's one ticker, its moving layer and its snap rules apply.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:honest_solitaire/engine/game.dart';

import 'board_layout.dart';
import 'card_motion.dart';
import 'pile_ref.dart';

/// When the last card lands.
const Duration dealDuration = Duration(milliseconds: 600);

/// The plan that deals [game] as laid out in [frames]/[layout], or null
/// when there is nothing to deal.
MotionPlan? planDeal(BoardFrames frames, BoardLayout layout, Game game) {
  final columns = switch (game) {
    KlondikeGame k => k.tableau.length,
    SpiderGame s => s.tableau.length,
  };
  // Where the cards leave from: Klondike's stock slot; Spider's next-row
  // sliver (the slivers stay drawn under the flying cards).
  final Rect from;
  final bool fromSliver;
  switch (game) {
    case KlondikeGame():
      from = layout.slots[const StockPile()]!;
      fromSliver = false;
    case SpiderGame():
      final slivers = layout.cards[const StockPile()] ?? const <Rect>[];
      from = slivers.isNotEmpty
          ? slivers.first
          : layout.slots[const StockPile()]!;
      fromSliver = slivers.isNotEmpty;
  }
  // Dealing order: column by column on screen, left to right, then down.
  final order = <CardFrame>[];
  for (var c = 0; c < columns; c++) {
    final ids = frames.ids[TableauPile(c)] ?? const <int>[];
    for (final id in ids) {
      order.add(frames.byId[id]!);
    }
  }
  if (order.isEmpty) return null;
  final flight = slideDuration.inMilliseconds;
  final span = math.max(0, dealDuration.inMilliseconds - flight);
  final step = order.length > 1 ? span / (order.length - 1) : 0.0;
  final motions = <CardMotion>[];
  for (var i = 0; i < order.length; i++) {
    final f = order[i];
    final start = (i * step).round();
    final end = start + flight;
    final flips = f.card.faceUp; // dealt face down, the top ones turn up
    motions.add(
      CardMotion(
        id: f.id,
        before: f.card.down,
        after: f.card,
        from: fromSliver
            ? from
            : Rect.fromLTWH(from.left, from.top, f.rect.width, f.rect.height),
        to: f.rect,
        startMs: start,
        endMs: end,
        flipStartMs: end,
        flipEndMs: flips ? end + flipDuration.inMilliseconds : end,
        toPile: f.pile,
        toIndex: f.index,
      ),
    );
  }
  return MotionPlan(motions);
}
