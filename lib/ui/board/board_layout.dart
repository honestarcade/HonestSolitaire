/// Where every card and slot goes (#73): a pure function from a game, the
/// safe area and the display options to rects, following the design's
/// 390-point frame scaled to the phone.
///
/// The design's y values are measured from its frame top minus the 44-point
/// status area, so here the top bar starts at 0 and the top row at 48.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../settings/display_options.dart';
import 'pile_ref.dart';

/// The design's frame width; every value below is in these points.
const double designWidth = 390;

/// Boards wider than this are centred at this width.
const double maxBoardWidth = 480;

const double _topBarHeight = 44;
const double _topRowTop = 48;
const double _toolRowHeight = 84;
const double _tableauGap = 8; // between the tableau bottom and the tool row
const double _compressMargin = 4;
const double _minFaceUpOffset = 7;
const double _minFaceDownOffset = 3;
const double _wasteFan = 9;
const double _wasteExtra = 18;
const double _minHit = 48; // dp, unscaled

// Spider top row (unchanged by Large cards).
const double _sliverWidth = 26;
const double _sliverHeight = 36;
const double _sliverStep = 7;
const double _completedWidth = 20;
const double _completedStep = 20;
const double _spiderTopRowY = 2;
const double _spiderMargin = 14;
const double _spiderTableauTop = 58;

class BoardLayout {
  const BoardLayout({
    required this.scale,
    required this.boardRect,
    required this.cardSize,
    required this.radius,
    required this.topRowRadius,
    required this.narrow,
    required this.faceUpOffset,
    required this.faceDownOffset,
    required this.topBar,
    required this.topRow,
    required this.tableau,
    required this.toolRow,
    required this.slots,
    required this.cards,
    required this.columnStrips,
    required this.hitAreas,
  });

  /// Board width over the design's 390.
  final double scale;

  /// The (possibly capped and centred) board within the safe area.
  final Rect boardRect;
  final Size cardSize;
  final double radius;

  /// Spider's sliver and slot radius.
  final double topRowRadius;

  /// The card proportion set: Spider's narrow cards.
  final bool narrow;

  /// The uncompressed fan offsets, scaled.
  final double faceUpOffset;
  final double faceDownOffset;

  final Rect topBar;
  final Rect topRow;
  final Rect tableau;
  final Rect toolRow;

  /// One rect per slot: stock, waste (cw + 18 wide), foundations, each
  /// tableau column's base, Spider stock (the group) and completed slots.
  final Map<BoardPile, Rect> slots;

  /// One rect per card, by pile and index, bottom to top.
  final Map<BoardPile, List<Rect>> cards;

  /// The tableau columns' hit strips, widened to the gap midpoints.
  final List<Rect> columnStrips;

  /// Top-row hit areas, at least 48 dp each.
  final Map<BoardPile, Rect> hitAreas;

  @override
  bool operator ==(Object other) =>
      other is BoardLayout &&
      other.scale == scale &&
      other.boardRect == boardRect &&
      other.cardSize == cardSize &&
      other.radius == radius &&
      other.narrow == narrow &&
      other.topBar == topBar &&
      other.topRow == topRow &&
      other.tableau == tableau &&
      other.toolRow == toolRow &&
      _sameMap(other.slots, slots) &&
      _sameListMap(other.cards, cards) &&
      _sameList(other.columnStrips, columnStrips);

  @override
  int get hashCode => Object.hash(
    scale,
    boardRect,
    cardSize,
    radius,
    narrow,
    topBar,
    tableau,
    toolRow,
    slots.length,
    cards.length,
  );
}

bool _sameMap(Map<BoardPile, Rect> a, Map<BoardPile, Rect> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

bool _sameList(List<Rect> a, List<Rect> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameListMap(Map<BoardPile, List<Rect>> a, Map<BoardPile, List<Rect>> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final o = b[e.key];
    if (o == null || !_sameList(o, e.value)) return false;
  }
  return true;
}

/// The geometry shared by the two games for one screen.
class _Frame {
  _Frame(Size safeArea, {required bool klondike, required bool large}) {
    final width = math.min(safeArea.width, maxBoardWidth);
    scale = width / designWidth;
    left = (safeArea.width - width) / 2;
    boardRect = Rect.fromLTWH(left, 0, width, safeArea.height);
    if (klondike) {
      cardSize = large
          ? Size(52 * scale, 78 * scale)
          : Size(48 * scale, 72 * scale);
      columns = 7;
      gap = large ? (designWidth - 7 * 52) / 6 * scale : 5 * scale;
      radius = 6 * scale;
      faceUp = (large ? 19 : 17) * scale;
      faceDown = 6 * scale;
    } else {
      cardSize = large
          ? Size(36 * scale, 54 * scale)
          : Size(34 * scale, 52 * scale);
      columns = 10;
      gap = 3 * scale;
      radius = 5 * scale;
      faceUp = (large ? 15 : 14) * scale;
      faceDown = 5 * scale;
    }
    final totalW = columns * cardSize.width + (columns - 1) * gap;
    x0 = left + (width - totalW) / 2;
    topBar = Rect.fromLTWH(left, 0, width, _topBarHeight * scale);
    final topRowTop = _topRowTop * scale;
    final topRowHeight = klondike ? cardSize.height : 44 * scale;
    topRow = Rect.fromLTWH(left, topRowTop, width, topRowHeight);
    final tableauTop = klondike
        ? topRowTop + cardSize.height + 14 * scale
        : topRowTop + _spiderTableauTop * scale;
    toolRow = Rect.fromLTWH(
      left,
      safeArea.height - _toolRowHeight * scale,
      width,
      _toolRowHeight * scale,
    );
    var tableauBottom = toolRow.top - _tableauGap * scale;
    // A safe area too short for the layout keeps at least one card height
    // and lets compression do the rest.
    if (tableauBottom < tableauTop + cardSize.height) {
      tableauBottom = tableauTop + cardSize.height;
    }
    tableau = Rect.fromLTRB(left, tableauTop, left + width, tableauBottom);
  }

  late final double scale;
  late final double left;
  late final Rect boardRect;
  late final Size cardSize;
  late final int columns;
  late final double gap;
  late final double radius;
  late final double faceUp;
  late final double faceDown;
  late final double x0;
  late final Rect topBar;
  late final Rect topRow;
  late final Rect tableau;
  late final Rect toolRow;

  double columnX(int c) => x0 + c * (cardSize.width + gap);

  /// Mirrors a rect across the board's vertical centre line.
  Rect mirror(Rect r) => Rect.fromLTWH(
    boardRect.left + boardRect.right - r.right,
    r.top,
    r.width,
    r.height,
  );

  Rect widen(Rect r) {
    final w = math.max(r.width, _minHit);
    final h = math.max(r.height, _minHit);
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }
}

/// Lays out [game] in a safe area of [safeArea] with [options].
BoardLayout layoutBoard(Game game, Size safeArea, DisplayOptions options) =>
    switch (game) {
      KlondikeGame k => _layoutKlondike(k, safeArea, options),
      SpiderGame s => _layoutSpider(s, safeArea, options),
    };

/// The rects of one tableau column's cards, top to bottom of the pile
/// (index 0 first). Face-up offsets compress evenly to keep the column
/// above the tableau bottom, never below 7 points; if that is not enough,
/// face-down offsets shrink smoothly to 3. [peek] expands to the
/// uncompressed offsets, compressing only against the tableau bottom itself.
List<Rect> layoutColumn(
  Game game,
  int column,
  BoardLayout layout, {
  bool peek = false,
}) {
  final pile = switch (game) {
    KlondikeGame k => k.tableau[column],
    SpiderGame s => s.tableau[column],
  };
  final base = layout.slots[TableauPile(column)]!;
  return _columnRects(
    pile,
    base,
    layout.tableau.bottom,
    layout.faceUpOffset,
    layout.faceDownOffset,
    layout.scale,
    margin: peek ? 0 : _compressMargin * layout.scale,
  );
}

List<Rect> _columnRects(
  List<Card> pile,
  Rect base,
  double bottom,
  double faceUp0,
  double faceDown0,
  double scale, {
  required double margin,
}) {
  var ups = 0;
  for (final c in pile) {
    if (c.faceUp) ups++;
  }
  final downs = pile.length - ups;
  var up = faceUp0;
  var down = faceDown0;
  final avail = bottom - base.top - base.height - margin;
  final need = downs * down + math.max(0, ups - 1) * up;
  if (need > avail) {
    final minUp = _minFaceUpOffset * scale;
    if (ups > 1) {
      up = math.max(minUp, (avail - downs * down) / (ups - 1));
    }
    final stillNeed = downs * down + math.max(0, ups - 1) * up;
    if (stillNeed > avail && downs > 0) {
      down = math.max(
        _minFaceDownOffset * scale,
        (avail - math.max(0, ups - 1) * up) / downs,
      );
    }
  }
  final out = <Rect>[];
  var y = base.top;
  for (final c in pile) {
    out.add(Rect.fromLTWH(base.left, y, base.width, base.height));
    y += c.faceUp ? up : down;
  }
  return out;
}

BoardLayout _layoutKlondike(
  KlondikeGame game,
  Size safeArea,
  DisplayOptions options,
) {
  final f = _Frame(safeArea, klondike: true, large: options.largeCards);
  final cw = f.cardSize.width;
  final ch = f.cardSize.height;
  final y = f.topRow.top;
  final slots = <BoardPile, Rect>{};
  final cards = <BoardPile, List<Rect>>{};
  final hits = <BoardPile, Rect>{};

  // Right-handed positions, mirrored as a whole for left-handed play.
  var stock = Rect.fromLTWH(f.columnX(0), y, cw, ch);
  var waste = Rect.fromLTWH(f.columnX(1), y, cw + _wasteExtra * f.scale, ch);
  final foundations = <Suit, Rect>{
    for (final suit in Suit.values)
      suit: Rect.fromLTWH(f.columnX(3 + suit.index), y, cw, ch),
  };
  var fanDirection = 1.0;
  if (options.leftHanded) {
    stock = f.mirror(stock);
    waste = f.mirror(waste);
    for (final suit in Suit.values) {
      foundations[suit] = f.mirror(foundations[suit]!);
    }
    fanDirection = -1.0;
  }
  slots[const StockPile()] = stock;
  slots[const WastePile()] = waste;
  hits[const StockPile()] = f.widen(stock);
  hits[const WastePile()] = f.widen(waste);
  cards[const StockPile()] = List.filled(game.stock.length, stock);

  // The waste fans the cards of the last draw, 9 points apart, rightward
  // (leftward when mirrored); older cards stack at the slot origin.
  final fanned = math.min(game.lastDrawCount, game.waste.length);
  final wasteOrigin = options.leftHanded ? waste.right - cw : waste.left;
  final wasteCards = <Rect>[];
  for (var i = 0; i < game.waste.length; i++) {
    final k = i - (game.waste.length - fanned);
    final dx = k > 0 ? k * _wasteFan * f.scale * fanDirection : 0.0;
    wasteCards.add(Rect.fromLTWH(wasteOrigin + dx, y, cw, ch));
  }
  cards[const WastePile()] = wasteCards;

  for (final suit in Suit.values) {
    final pile = FoundationPile(suit);
    slots[pile] = foundations[suit]!;
    hits[pile] = f.widen(foundations[suit]!);
    cards[pile] = List.filled(
      game.foundations[suit.index].length,
      foundations[suit]!,
    );
  }

  final strips = <Rect>[];
  for (var c = 0; c < 7; c++) {
    final base = Rect.fromLTWH(f.columnX(c), f.tableau.top, cw, ch);
    slots[TableauPile(c)] = base;
    cards[TableauPile(c)] = _columnRects(
      game.tableau[c],
      base,
      f.tableau.bottom,
      f.faceUp,
      f.faceDown,
      f.scale,
      margin: _compressMargin * f.scale,
    );
    final stripLeft = c == 0 ? f.boardRect.left : base.left - f.gap / 2;
    final stripRight = c == 6 ? f.boardRect.right : base.right + f.gap / 2;
    strips.add(
      Rect.fromLTRB(stripLeft, f.tableau.top, stripRight, f.tableau.bottom),
    );
  }

  return BoardLayout(
    scale: f.scale,
    boardRect: f.boardRect,
    cardSize: f.cardSize,
    radius: f.radius,
    topRowRadius: 4 * f.scale,
    narrow: false,
    faceUpOffset: f.faceUp,
    faceDownOffset: f.faceDown,
    topBar: f.topBar,
    topRow: f.topRow,
    tableau: f.tableau,
    toolRow: f.toolRow,
    slots: slots,
    cards: cards,
    columnStrips: strips,
    hitAreas: hits,
  );
}

BoardLayout _layoutSpider(
  SpiderGame game,
  Size safeArea,
  DisplayOptions options,
) {
  final f = _Frame(safeArea, klondike: false, large: options.largeCards);
  final cw = f.cardSize.width;
  final ch = f.cardSize.height;
  final s = f.scale;
  final y = f.topRow.top + _spiderTopRowY * s;
  final slots = <BoardPile, Rect>{};
  final cards = <BoardPile, List<Rect>>{};
  final hits = <BoardPile, Rect>{};

  final rows = game.stock.length;
  final groupWidth =
      _sliverWidth * s + (rows > 0 ? (rows - 1) * _sliverStep * s : 0);
  var stock = Rect.fromLTWH(
    f.boardRect.right - _spiderMargin * s - groupWidth,
    y,
    groupWidth,
    _sliverHeight * s,
  );
  // Sliver index 0 is the next row to deal, drawn rightmost (on top).
  var slivers = <Rect>[
    for (var i = 0; i < rows; i++)
      Rect.fromLTWH(
        stock.left + (rows - 1 - i) * _sliverStep * s,
        y,
        _sliverWidth * s,
        _sliverHeight * s,
      ),
  ];
  var completed = <Rect>[
    for (var i = 0; i < 8; i++)
      Rect.fromLTWH(
        f.boardRect.left + _spiderMargin * s + i * _completedStep * s,
        y,
        _completedWidth * s,
        _sliverHeight * s,
      ),
  ];
  if (options.leftHanded) {
    stock = f.mirror(stock);
    slivers = [for (final r in slivers) f.mirror(r)];
    completed = [for (final r in completed) f.mirror(r)];
  }
  slots[const StockPile()] = stock;
  // The stock's hit area keeps a full sliver's width plus the group so the
  // last sliver stays easy to hit.
  hits[const StockPile()] = f.widen(stock);
  cards[const StockPile()] = slivers;
  for (var i = 0; i < 8; i++) {
    final pile = CompletedPile(i);
    slots[pile] = completed[i];
    hits[pile] = f.widen(completed[i]);
    cards[pile] = i < game.completed.length ? [completed[i]] : const [];
  }

  final strips = <Rect>[];
  for (var c = 0; c < 10; c++) {
    final base = Rect.fromLTWH(f.columnX(c), f.tableau.top, cw, ch);
    slots[TableauPile(c)] = base;
    cards[TableauPile(c)] = _columnRects(
      game.tableau[c],
      base,
      f.tableau.bottom,
      f.faceUp,
      f.faceDown,
      f.scale,
      margin: _compressMargin * f.scale,
    );
    final stripLeft = c == 0 ? f.boardRect.left : base.left - f.gap / 2;
    final stripRight = c == 9 ? f.boardRect.right : base.right + f.gap / 2;
    strips.add(
      Rect.fromLTRB(stripLeft, f.tableau.top, stripRight, f.tableau.bottom),
    );
  }

  return BoardLayout(
    scale: f.scale,
    boardRect: f.boardRect,
    cardSize: f.cardSize,
    radius: f.radius,
    topRowRadius: 4 * s,
    narrow: true,
    faceUpOffset: f.faceUp,
    faceDownOffset: f.faceDown,
    topBar: f.topBar,
    topRow: f.topRow,
    tableau: f.tableau,
    toolRow: f.toolRow,
    slots: slots,
    cards: cards,
    columnStrips: strips,
    hitAreas: hits,
  );
}

/// The pile and card index under [point]: top-row piles win any overlap (the
/// topmost fanned waste card, the top foundation card, null for the stock,
/// an empty pile or a completed slot); in a column the topmost card wins and
/// the strip below its last card hits the column with a null index.
(BoardPile, int?)? hitTest(BoardLayout layout, Offset point) {
  // Exact slot rects first, so neighbours whose widened areas overlap (the
  // Spider completed slots, 20 apart) resolve to the one really under the
  // finger; the widened areas then catch near misses.
  BoardPile? topRowPile;
  for (final entry in layout.hitAreas.entries) {
    if (layout.slots[entry.key]!.contains(point)) {
      topRowPile = entry.key;
      break;
    }
  }
  if (topRowPile == null) {
    var best = double.infinity;
    for (final entry in layout.hitAreas.entries) {
      if (!entry.value.contains(point)) continue;
      final d = (layout.slots[entry.key]!.center - point).distanceSquared;
      if (d < best) {
        best = d;
        topRowPile = entry.key;
      }
    }
  }
  if (topRowPile != null) {
    final pile = topRowPile;
    if (pile is StockPile || pile is CompletedPile) return (pile, null);
    final rects = layout.cards[pile] ?? const [];
    for (var i = rects.length - 1; i >= 0; i--) {
      if (rects[i].contains(point)) return (pile, i);
    }
    return (pile, rects.isEmpty ? null : rects.length - 1);
  }
  for (var c = 0; c < layout.columnStrips.length; c++) {
    if (!layout.columnStrips[c].contains(point)) continue;
    final pile = TableauPile(c);
    final rects = layout.cards[pile]!;
    for (var i = rects.length - 1; i >= 0; i--) {
      if (rects[i].contains(point)) return (pile, i);
    }
    return (pile, null);
  }
  return null;
}
