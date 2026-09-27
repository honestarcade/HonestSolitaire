/// Card motion (#99): how the board animates from one committed layout to
/// the next. The engine state is always the committed state; this is
/// presentation only, driven by one board-level ticker, and nothing of it
/// runs under [AppMotion.none].
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../settings/play_settings.dart';
import 'board_layout.dart';
import 'pile_ref.dart';

/// Whether the app animates at all: off when the phone asks for no
/// animations or the Card animations setting is off (owner, round one).
enum AppMotion {
  full,
  none;

  static AppMotion of(BuildContext context, PlaySettings settings) =>
      MediaQuery.disableAnimationsOf(context) || !settings.cardAnimations
      ? AppMotion.none
      : AppMotion.full;
}

const Duration slideDuration = Duration(milliseconds: 180);
const Duration flipDuration = Duration(milliseconds: 150);
const Duration settleDuration = Duration(milliseconds: 120);
const Duration drawStagger = Duration(milliseconds: 40);
const Duration dealStagger = Duration(milliseconds: 30);
const Curve slideCurve = Curves.easeOutCubic;

/// Where one card sits in a committed layout.
class CardFrame {
  const CardFrame(this.id, this.card, this.pile, this.index, this.rect);

  final int id;
  final Card card;
  final BoardPile pile;
  final int index;
  final Rect rect;
}

/// Every card's frame, by id and by pile.
class BoardFrames {
  const BoardFrames(this.byId, this.ids, this.completed);

  final Map<int, CardFrame> byId;

  /// Each pile's ids in index order.
  final Map<BoardPile, List<int>> ids;

  /// Spider's completed-run count (the King's slot when a run leaves).
  final int completed;

  int? idAt(BoardPile pile, int index) {
    final list = ids[pile];
    return list != null && index < list.length ? list[index] : null;
  }
}

/// A stable id for a card without one: rank, suit and occurrence order.
int _fallbackId(Card card, Map<(int, Suit), int> seen) {
  final key = (card.rank, card.suit);
  final n = seen[key] ?? 0;
  seen[key] = n + 1;
  return 1 << 20 | card.suit.index << 12 | card.rank << 6 | n;
}

/// The frames of [game] laid out as [layout].
BoardFrames snapshotFrames(Game game, BoardLayout layout) {
  final byId = <int, CardFrame>{};
  final ids = <BoardPile, List<int>>{};
  final seen = <(int, Suit), int>{};
  void pile(BoardPile p, List<Card> cards, List<Rect> rects) {
    final list = <int>[];
    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final id = card.id >= 0 ? card.id : _fallbackId(card, seen);
      final rect = i < rects.length ? rects[i] : rects.last;
      byId[id] = CardFrame(id, card, p, i, rect);
      list.add(id);
    }
    ids[p] = list;
  }

  var completed = 0;
  switch (game) {
    case KlondikeGame k:
      for (var c = 0; c < klondikeColumns; c++) {
        pile(TableauPile(c), k.tableau[c], layout.cards[TableauPile(c)]!);
      }
      pile(const StockPile(), k.stock, layout.cards[const StockPile()]!);
      pile(const WastePile(), k.waste, layout.cards[const WastePile()]!);
      for (final suit in Suit.values) {
        pile(
          FoundationPile(suit),
          k.foundations[suit.index],
          layout.cards[FoundationPile(suit)]!,
        );
      }
    case SpiderGame s:
      for (var c = 0; c < spiderColumns; c++) {
        pile(TableauPile(c), s.tableau[c], layout.cards[TableauPile(c)]!);
      }
      // Stock rows sit under their sliver; a dealt card leaves from there.
      final slivers = layout.cards[const StockPile()] ?? const <Rect>[];
      final stockList = <int>[];
      for (var r = 0; r < s.stock.length; r++) {
        final rect = slivers.isEmpty
            ? layout.slots[const StockPile()]!
            : slivers[math.min(r, slivers.length - 1)];
        for (final card in s.stock[r]) {
          final id = card.id >= 0 ? card.id : _fallbackId(card, seen);
          byId[id] = CardFrame(id, card, const StockPile(), r, rect);
          stockList.add(id);
        }
      }
      ids[const StockPile()] = stockList;
      completed = s.completed.length;
  }
  return BoardFrames(byId, ids, completed);
}

/// Same piles by identity (a clock tick never re-plans).
bool samePiles(Game a, Game b) => switch ((a, b)) {
  (KlondikeGame a, KlondikeGame b) =>
    identical(a.tableau, b.tableau) &&
        identical(a.stock, b.stock) &&
        identical(a.waste, b.waste) &&
        identical(a.foundations, b.foundations),
  (SpiderGame a, SpiderGame b) =>
    identical(a.tableau, b.tableau) &&
        identical(a.stock, b.stock) &&
        identical(a.completed, b.completed),
  _ => false,
};

/// One card's motion within a plan: a slide from [from] to [to] between
/// [startMs] and [endMs], then a flip to [after]'s face between
/// [flipStartMs] and [flipEndMs] when the face changed.
class CardMotion {
  const CardMotion({
    required this.id,
    required this.before,
    required this.after,
    required this.from,
    required this.to,
    required this.startMs,
    required this.endMs,
    required this.flipStartMs,
    required this.flipEndMs,
    this.toPile,
    this.toIndex = 0,
    this.narrow = false,
  });

  final int id;
  final Card before;
  final Card after;
  final Rect from;
  final Rect to;
  final int startMs;
  final int endMs;
  final int flipStartMs;
  final int flipEndMs;

  /// Where the card lands; null for a King leaving for its completed slot.
  final BoardPile? toPile;
  final int toIndex;
  final bool narrow;

  bool get flips => flipEndMs > flipStartMs;
  int get lastMs => math.max(endMs, flipEndMs);
  bool doneAt(int ms) => ms >= lastMs;

  Rect rectAt(int ms) {
    if (endMs <= startMs) return to;
    final t = ((ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
    return Rect.lerp(from, to, slideCurve.transform(t))!;
  }

  /// 0..1 through the flip, or -1 when no flip is under way.
  double flipAt(int ms) {
    if (!flips || ms < flipStartMs) return -1;
    if (ms >= flipEndMs) return -1;
    return (ms - flipStartMs) / (flipEndMs - flipStartMs);
  }

  /// The face to draw at [ms]: the old one until half-way through the flip.
  Card cardAt(int ms) {
    if (!flips) return after;
    final f = flipAt(ms);
    if (f < 0) return ms >= flipEndMs ? after : before;
    return f < 0.5 ? before : after;
  }

  /// The horizontal scale at [ms]: 1 at rest, through 0 at half-flip.
  double scaleXAt(int ms) {
    final f = flipAt(ms);
    if (f < 0) return 1;
    return f < 0.5 ? 1 - 2 * f : 2 * f - 1;
  }
}

class MotionPlan {
  MotionPlan(this.motions, {this.completedSlot})
    : totalMs = motions.fold(0, (m, c) => math.max(m, c.lastMs)),
      byId = {for (final m in motions) m.id: m};

  final List<CardMotion> motions;
  final Map<int, CardMotion> byId;
  final int totalMs;

  /// The completed slot a King is still travelling to, hidden meanwhile.
  final int? completedSlot;

  bool get isEmpty => motions.isEmpty;

  /// The motions still in flight at [ms].
  Iterable<CardMotion> activeAt(int ms) => motions.where((m) => !m.doneAt(ms));
}

/// Plans the motion from [previous] to [next]: every card whose rect or
/// face changed slides and flips; cards that appear snap; a Spider run's
/// King slides to its completed slot. [dropRects] are where a released drag
/// left its cards (the settle starts there, in [settle]). [slide] is the
/// finish sweep's 60 ms during a sweep. Null when nothing moves.
MotionPlan? planMotion({
  required BoardFrames previous,
  required BoardFrames next,
  required BoardLayout layout,
  Map<int, Rect> dropRects = const {},
  Duration slide = slideDuration,
  Duration flip = flipDuration,
  Duration settle = settleDuration,
}) {
  final motions = <CardMotion>[];
  final drawOrder = <int>[]; // stock → waste cards, by destination index
  for (final n in next.byId.values) {
    final p = previous.byId[n.id];
    if (p == null) continue;
    if (p.pile is StockPile && n.pile is WastePile) drawOrder.add(n.index);
  }
  drawOrder.sort();
  // A card that only flips (the one a move uncovered) waits for the slides
  // to land; a card that slides and flips (a stock draw) flips as it lands.
  var landMs = 0;
  for (final n in next.byId.values) {
    final p = previous.byId[n.id];
    if (p != null && !_close(p.rect, n.rect)) {
      landMs = math.max(landMs, slide.inMilliseconds);
    }
  }
  for (final n in next.byId.values) {
    final p = previous.byId[n.id];
    if (p == null) continue;
    final moved = !_close(p.rect, n.rect);
    final flipped = p.card.faceUp != n.card.faceUp;
    if (!moved && !flipped) continue;
    var startMs = 0;
    if (p.pile is StockPile && n.pile is WastePile) {
      startMs = drawOrder.indexOf(n.index) * drawStagger.inMilliseconds;
    } else if (p.pile is StockPile && n.pile is TableauPile) {
      startMs = (n.pile as TableauPile).column * dealStagger.inMilliseconds;
    }
    final drop = dropRects[n.id];
    final from = drop ?? p.rect;
    final duration = drop != null ? settle : slide;
    final endMs = moved ? startMs + duration.inMilliseconds : startMs;
    final flipStart = moved ? endMs : landMs;
    final flipEnd = flipped ? flipStart + flip.inMilliseconds : flipStart;
    motions.add(
      CardMotion(
        id: n.id,
        before: p.card,
        after: n.card,
        from: from,
        to: n.rect,
        startMs: startMs,
        endMs: endMs,
        flipStartMs: flipStart,
        flipEndMs: flipEnd,
        toPile: n.pile,
        toIndex: n.index,
      ),
    );
  }
  int? completedSlot;
  if (next.completed > previous.completed) {
    // The run's King travels to the new slot; the other twelve vanish now.
    CardFrame? king;
    for (final p in previous.byId.values) {
      if (next.byId.containsKey(p.id)) continue;
      if (p.card.rank == kingRank && (king == null || p.index < king.index)) {
        king = p;
      }
    }
    final slot = next.completed - 1;
    final to = layout.slots[CompletedPile(slot)];
    if (king != null && to != null) {
      completedSlot = slot;
      motions.add(
        CardMotion(
          id: king.id,
          before: king.card.up,
          after: king.card.up,
          from: king.rect,
          to: to,
          startMs: 0,
          endMs: slide.inMilliseconds,
          flipStartMs: slide.inMilliseconds,
          flipEndMs: slide.inMilliseconds,
          narrow: true,
        ),
      );
    }
  } else if (next.completed < previous.completed) {
    // An undone completion: the run comes back from its slot as one group.
    final from = layout.slots[CompletedPile(previous.completed - 1)];
    if (from != null) {
      for (final n in next.byId.values) {
        if (previous.byId.containsKey(n.id)) continue;
        motions.add(
          CardMotion(
            id: n.id,
            before: n.card,
            after: n.card,
            from: from,
            to: n.rect,
            startMs: 0,
            endMs: slide.inMilliseconds,
            flipStartMs: slide.inMilliseconds,
            flipEndMs: slide.inMilliseconds,
            toPile: n.pile,
            toIndex: n.index,
          ),
        );
      }
    }
  }
  if (motions.isEmpty) return null;
  return MotionPlan(motions, completedSlot: completedSlot);
}

bool _close(Rect a, Rect b) =>
    (a.left - b.left).abs() < 0.01 &&
    (a.top - b.top).abs() < 0.01 &&
    (a.width - b.width).abs() < 0.01 &&
    (a.height - b.height).abs() < 0.01;
