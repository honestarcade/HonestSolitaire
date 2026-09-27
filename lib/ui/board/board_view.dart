/// The board: the felt, the slots and every card at its layout position,
/// always exactly the engine's state (#74).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../card/card_style.dart';
import '../card/playing_card.dart';
import '../game/game_controller.dart';
import '../game/win_card.dart';
import '../settings/display_options.dart';
import '../theme/palette.dart';
import 'board_layout.dart';
import 'board_pointer.dart';
import 'pile_ref.dart';
import 'slot_painter.dart';

/// The design's felt: radial-gradient(120% 80% at 50% 0%, #0a3a80, #05285F
/// 52%, #031634).
const feltGradient = RadialGradient(
  center: Alignment.topCenter,
  radius: 1.2,
  colors: [Palette.feltTop, Palette.feltMid, Palette.feltBottom],
  stops: [0, 0.52, 1],
  transform: _FeltTransform(),
);

class _FeltTransform extends GradientTransform {
  const _FeltTransform();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Flutter's radius is a fraction of the shorter side; the design's
    // ellipse is 120 % of the width by 80 % of the height.
    final shorter = math.min(bounds.width, bounds.height);
    final sx = bounds.width / shorter;
    final sy = (bounds.height * 0.8) / (shorter * 1.2);
    return Matrix4.identity()
      ..translateByDouble(bounds.center.dx, bounds.top, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-bounds.center.dx, -bounds.top, 0, 1);
  }
}

// The design's per-slot outline alphas.
const _stockEdge = Color(0x38FFFFFF); // .22
const _wasteEdge = Color(0x24FFFFFF); // .14
const _foundationEdge = Color(0x33FFFFFF); // .20
const _columnEdge = Color(0x1FFFFFFF); // .12
const _columnEdgeActive = Color(0x8000D6B4); // teal .5
const _spiderEmptyEdge = Color(0x29FFFFFF); // .16
const _completedEdge = Color(0x24FFFFFF); // .14
const _slotFill = Color(0x0AFFFFFF); // .04
const _hintEdge = Palette.hintRing;

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.controller,
    this.padding = EdgeInsets.zero,
    this.topBar,
    this.toolRow,
  });

  final GameController controller;

  /// The system insets: the felt paints behind them, the board lays out
  /// inside them.
  final EdgeInsets padding;
  final WidgetBuilder? topBar;
  final WidgetBuilder? toolRow;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: shakeDuration,
  );
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: springBackDuration,
  );
  late final Animation<double> _springCurve = CurvedAnimation(
    parent: _spring,
    curve: Curves.easeOutCubic,
  );
  int _shakeSequence = 0;
  int _springSequence = 0;
  _LayoutCache? _cache;

  @override
  void dispose() {
    _shake.dispose();
    _spring.dispose();
    super.dispose();
  }

  BoardLayout _layout(Game game, Size size, DisplayOptions options) {
    final cache = _cache;
    if (cache != null && cache.matches(game, size, options)) {
      return cache.layout;
    }
    final layout = layoutBoard(game, size, options);
    _cache = _LayoutCache(game, size, options, layout);
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: feltGradient),
        child: Padding(
          padding: widget.padding,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              controller,
              controller.displayOptions,
            ]),
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final game = controller.shown;
                final options = controller.display;
                final layout = _layout(game, size, options);
                final shake = controller.shake;
                if (shake != null && shake.sequence != _shakeSequence) {
                  _shakeSequence = shake.sequence;
                  _shake.forward(from: 0);
                }
                final spring = controller.springBack;
                if (spring != null && spring.sequence != _springSequence) {
                  _springSequence = spring.sequence;
                  _spring.forward(from: 0);
                }
                return _Board(
                  controller: controller,
                  layout: layout,
                  shakeAnimation: _shake,
                  springAnimation: _springCurve,
                  topBar: widget.topBar?.call(context),
                  toolRow: widget.toolRow?.call(context),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutCache {
  _LayoutCache(this.game, this.size, this.options, this.layout);

  final Game game;
  final Size size;
  final DisplayOptions options;
  final BoardLayout layout;

  /// Same piles (by identity, so a clock tick never re-lays-out), size and
  /// options.
  bool matches(Game other, Size otherSize, DisplayOptions otherOptions) {
    if (otherSize != size || otherOptions != options) return false;
    return switch ((game, other)) {
      (KlondikeGame a, KlondikeGame b) =>
        identical(a.tableau, b.tableau) &&
            identical(a.stock, b.stock) &&
            identical(a.waste, b.waste) &&
            identical(a.foundations, b.foundations) &&
            a.lastDrawCount == b.lastDrawCount,
      (SpiderGame a, SpiderGame b) =>
        identical(a.tableau, b.tableau) &&
            identical(a.stock, b.stock) &&
            identical(a.completed, b.completed),
      _ => false,
    };
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.controller,
    required this.layout,
    required this.shakeAnimation,
    required this.springAnimation,
    this.topBar,
    this.toolRow,
  });

  final GameController controller;
  final BoardLayout layout;
  final Animation<double> shakeAnimation;
  final Animation<double> springAnimation;

  /// The run lifted out of its pile by a drag or a spring-back: (pile,
  /// first index), painted in the top layer instead.
  (BoardPile, int)? get _lifted {
    final d = controller.dragging;
    if (d != null) return (d.pile, d.start);
    final s = controller.springBack;
    if (s != null) return (s.pile, s.start);
    return null;
  }

  final Widget? topBar;
  final Widget? toolRow;

  @override
  Widget build(BuildContext context) {
    final game = controller.shown;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final children = <Widget>[];
    final peek = controller.peekColumn;
    final peekLayer = <Widget>[];
    switch (game) {
      case KlondikeGame k:
        _klondikeSlots(children, k);
        for (var c = 0; c < klondikeColumns; c++) {
          if (c == peek) {
            _cards(
              peekLayer,
              TableauPile(c),
              k.tableau[c],
              dpr,
              rects: layoutColumn(k, c, layout, peek: true),
            );
          } else {
            _cards(children, TableauPile(c), k.tableau[c], dpr);
          }
        }
        _cards(children, const StockPile(), k.stock, dpr);
        _cards(children, const WastePile(), k.waste, dpr);
        for (final suit in Suit.values) {
          _cards(
            children,
            FoundationPile(suit),
            k.foundations[suit.index],
            dpr,
          );
        }
      case SpiderGame s:
        _spiderSlots(children, s);
        for (var c = 0; c < spiderColumns; c++) {
          if (c == peek) {
            _cards(
              peekLayer,
              TableauPile(c),
              s.tableau[c],
              dpr,
              rects: layoutColumn(s, c, layout, peek: true),
            );
          } else {
            _cards(children, TableauPile(c), s.tableau[c], dpr);
          }
        }
    }
    _dragTargets(children);
    children.addAll(peekLayer);
    if (topBar != null) {
      children.add(Positioned.fromRect(rect: layout.topBar, child: topBar!));
    }
    if (toolRow != null) {
      children.add(Positioned.fromRect(rect: layout.toolRow, child: toolRow!));
    }
    _dragLayer(children);
    children.add(GameOverlays(controller: controller, scale: layout.scale));
    return BoardPointer(
      controller: controller,
      layout: layout,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }

  Widget _slot(
    Rect rect,
    SlotPainter painter, {
    Key? key,
    String? label,
    BoardPile? pile,
  }) {
    Widget paint = CustomPaint(key: key, painter: painter, size: rect.size);
    if (label != null) {
      paint = Semantics(
        button: true,
        label: label,
        onTap: pile == null ? null : () => controller.tapPile(pile, null),
        child: paint,
      );
    }
    return Positioned.fromRect(rect: rect, child: paint);
  }

  static String _capital(String s) => s[0].toUpperCase() + s.substring(1);

  void _klondikeSlots(List<Widget> out, KlondikeGame game) {
    final r = layout.radius;
    out.add(
      _slot(
        layout.slots[const StockPile()]!,
        SlotPainter(
          radius: r,
          edgeColor: _slotEdge(const StockPile(), _stockEdge),
          fill: game.stock.isEmpty ? _slotFill : null,
          recycle: game.stock.isEmpty && game.waste.isNotEmpty,
          recycleSize: 14 * layout.scale,
        ),
        key: const Key('slot-stock'),
        pile: const StockPile(),
        label: game.stock.isNotEmpty
            ? 'Stock, ${game.stock.length} cards'
            : game.waste.isNotEmpty
            ? 'Recycle'
            : 'Stock, empty',
      ),
    );
    out.add(
      _slot(
        layout.slots[const WastePile()]!,
        SlotPainter(radius: r, edgeColor: _wasteEdge),
        key: const Key('slot-waste'),
        pile: const WastePile(),
        label: game.waste.isEmpty
            ? 'Waste, empty'
            : 'Waste, ${game.waste.length} cards',
      ),
    );
    for (final suit in Suit.values) {
      final empty = game.foundations[suit.index].isEmpty;
      out.add(
        _slot(
          layout.slots[FoundationPile(suit)]!,
          SlotPainter(
            radius: r,
            edgeColor: _slotEdge(FoundationPile(suit), _foundationEdge),
            fill: empty ? _slotFill : null,
            placeholderSuit: empty ? suit : null,
          ),
          key: Key('slot-f-${suit.name}'),
          pile: FoundationPile(suit),
          label: empty
              ? '${_capital(suit.name)} foundation, empty'
              : '${_capital(suit.name)} foundation, up to '
                    '${game.foundations[suit.index].last.rankName}',
        ),
      );
    }
    for (var c = 0; c < klondikeColumns; c++) {
      if (game.tableau[c].isNotEmpty) continue;
      out.add(
        _slot(
          layout.slots[TableauPile(c)]!,
          SlotPainter(
            radius: r,
            edgeColor: _slotEdge(TableauPile(c), _columnEdge, selectable: true),
          ),
          key: Key('slot-t$c'),
          pile: TableauPile(c),
          label: 'Empty column ${c + 1}',
        ),
      );
    }
  }

  void _spiderSlots(List<Widget> out, SpiderGame game) {
    final r = layout.radius;
    final tr = layout.topRowRadius;
    if (game.stock.isEmpty) {
      out.add(
        Positioned.fromRect(
          rect: layout.slots[const StockPile()]!,
          child: Semantics(
            button: true,
            label: 'Stock, no deals left',
            excludeSemantics: true,
            onTap: () => controller.tapPile(const StockPile(), null),
            child: CustomPaint(
              key: const Key('stock-empty'),
              painter: SlotPainter(
                radius: tr,
                edgeColor: _slotEdge(const StockPile(), _spiderEmptyEdge),
              ),
              child: Center(
                child: Text(
                  'EMPTY',
                  style: TextStyle(
                    fontSize: 9 * layout.scale,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.06 * 9 * layout.scale,
                    color: const Color(0x4DFFFFFF),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      final slivers = layout.cards[const StockPile()]!;
      final rows = slivers.length;
      out.add(
        Positioned.fromRect(
          rect: layout.slots[const StockPile()]!,
          child: Semantics(
            button: true,
            label: 'Stock, $rows deal${rows == 1 ? '' : 's'} left',
            onTap: () => controller.tapPile(const StockPile(), null),
            child: const SizedBox.expand(),
          ),
        ),
      );
      for (var i = rows - 1; i >= 0; i--) {
        out.add(
          Positioned.fromRect(
            rect: slivers[i],
            child: ExcludeSemantics(
              child: PlayingCard(
                key: Key('stock-sliver-$i'),
                card: null,
                size: slivers[i].size,
                back: controller.display.cardBack,
                ring: (controller.currentHint?.stock ?? false)
                    ? CardRing.hinted
                    : CardRing.none,
                edge: false,
                radius: tr,
              ),
            ),
          ),
        );
      }
    }
    for (var i = 0; i < 8; i++) {
      final rect = layout.slots[CompletedPile(i)]!;
      if (i < game.completed.length) {
        out.add(
          Positioned.fromRect(
            rect: rect,
            child: Semantics(
              label: 'Completed run, ${game.completed[i].name}',
              excludeSemantics: true,
              child: PlayingCard(
                key: Key('completed-$i'),
                card: Card(kingRank, game.completed[i], faceUp: true),
                size: rect.size,
                back: controller.display.cardBack,
                narrow: true,
                radius: tr,
              ),
            ),
          ),
        );
      } else {
        out.add(
          _slot(
            rect,
            SlotPainter(radius: tr, edgeColor: _completedEdge),
            key: Key('completed-slot-$i'),
          ),
        );
      }
    }
    for (var c = 0; c < spiderColumns; c++) {
      if (game.tableau[c].isNotEmpty) continue;
      out.add(
        _slot(
          layout.slots[TableauPile(c)]!,
          SlotPainter(
            radius: r,
            edgeColor: _slotEdge(TableauPile(c), _columnEdge, selectable: true),
          ),
          key: Key('slot-t$c'),
          pile: TableauPile(c),
          label: 'Empty column ${c + 1}',
        ),
      );
    }
  }

  CardRing _ring(BoardPile pile, int index) {
    final sel = controller.selection;
    if (sel != null && sel.$1 == pile && index >= sel.$2) {
      return CardRing.selected;
    }
    final hint = controller.currentHint;
    if (hint != null) {
      if (hint.stock && pile is StockPile) {
        final rects = layout.cards[pile]!;
        return index == rects.length - 1 ? CardRing.hinted : CardRing.none;
      }
      if (hint.source == pile && hint.start != null && index >= hint.start!) {
        return CardRing.hinted;
      }
      if (hint.destination == pile) {
        final rects = layout.cards[pile];
        if (rects != null && index == rects.length - 1) return CardRing.hinted;
      }
    }
    return CardRing.none;
  }

  /// The outline colour of an empty slot: amber when it is the hint's
  /// destination (or the stock for a draw/recycle/deal hint), teal while a
  /// selection is active (columns), else the design's alpha.
  Color _slotEdge(BoardPile pile, Color base, {bool selectable = false}) {
    final hint = controller.currentHint;
    if (hint != null) {
      if (hint.destination == pile) return _hintEdge;
      if (hint.stock && pile is StockPile) return _hintEdge;
    }
    if (selectable && controller.selection != null) return _columnEdgeActive;
    return base;
  }

  /// The lifted run's cards, following the finger with the design's deeper
  /// shadow, or sliding home after an illegal drop. They keep their pile
  /// keys, so a test reads their positions like any card's.
  void _dragLayer(List<Widget> out) {
    final d = controller.dragging;
    if (d != null) {
      final rects = d.rects;
      for (var i = 0; i < d.cards.length; i++) {
        out.add(
          Positioned(
            left: rects[i].left,
            top: rects[i].top,
            child: PlayingCard(
              key: Key('card-${d.pile.token}-${d.start + i}'),
              card: d.cards[i],
              size: layout.cardSize,
              back: controller.display.cardBack,
              narrow: layout.narrow,
              radius: layout.radius,
              lifted: true,
            ),
          ),
        );
      }
      return;
    }
    final s = controller.springBack;
    if (s != null) {
      for (var i = 0; i < s.cards.length; i++) {
        out.add(
          AnimatedBuilder(
            animation: springAnimation,
            builder: (context, child) {
              final rect = Rect.lerp(
                s.from[i],
                s.to[i],
                springAnimation.value,
              )!;
              return Positioned(left: rect.left, top: rect.top, child: child!);
            },
            child: PlayingCard(
              key: Key('card-${s.pile.token}-${s.start + i}'),
              card: s.cards[i],
              size: layout.cardSize,
              back: controller.display.cardBack,
              narrow: layout.narrow,
              radius: layout.radius,
            ),
          ),
        );
      }
    }
  }

  /// While dragging, every pile that accepts the run outlines teal: around
  /// its top card, or its empty slot.
  void _dragTargets(List<Widget> out) {
    final d = controller.dragging;
    if (d == null) return;
    for (final pile in d.targets) {
      final cards = layout.cards[pile];
      final rect = cards != null && cards.isNotEmpty
          ? cards.last
          : layout.slots[pile];
      if (rect == null) continue;
      out.add(
        _slot(
          rect,
          SlotPainter(radius: layout.radius, edgeColor: _columnEdgeActive),
          key: Key('target-${pile.token}'),
        ),
      );
    }
  }

  void _cards(
    List<Widget> out,
    BoardPile pile,
    List<Card> cards,
    double dpr, {
    List<Rect>? rects,
  }) {
    rects ??= layout.cards[pile]!;
    final shake = controller.shake;
    final shaking = shake != null && shake.pile == pile;
    final lifted = _lifted;
    final liftedFrom = lifted != null && lifted.$1 == pile
        ? lifted.$2
        : cards.length;
    final raised = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      if (i >= liftedFrom) break; // painted by the drag layer
      final rect = rects[i];
      // Snap the origin to a device pixel; sizes stay fractional.
      final left = (rect.left * dpr).roundToDouble() / dpr;
      final top = (rect.top * dpr).roundToDouble() / dpr;
      final covered = i + 1 < cards.length && rects[i + 1] == rect;
      final ring = _ring(pile, i);
      Widget card = PlayingCard(
        key: Key('card-${pile.token}-$i'),
        card: cards[i],
        size: layout.cardSize,
        back: controller.display.cardBack,
        ring: ring,
        narrow: layout.narrow,
        radius: layout.radius,
      );
      if (covered) {
        card = Visibility(visible: false, maintainState: true, child: card);
      }
      final inShake = shaking && (shake.start == null || i >= shake.start!);
      final positioned = inShake
          ? AnimatedBuilder(
              animation: shakeAnimation,
              builder: (context, child) {
                final t = shakeAnimation.value;
                final dx = math.sin(t * 3 * 2 * math.pi) * 6 * (1 - t);
                return Positioned(left: left + dx, top: top, child: child!);
              },
              child: card,
            )
          : Positioned(left: left, top: top, child: card);
      if (inShake || ring == CardRing.selected) {
        raised.add(positioned);
      } else {
        out.add(positioned);
      }
    }
    out.addAll(raised);
  }
}
