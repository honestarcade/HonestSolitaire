// The short wins behind qa/a11y-sweep.md (#116), shared by
// tools/find_a11y_deals.dart (which scans deal numbers for them) and
// test/qa/a11y_sweep_test.dart (which reads the lines back out of the
// script and replays them through the game controller as TalkBack drives
// it). Pure Dart: the engine, the solver, the Spider beam search and the
// board's spoken words.
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/finish.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/engine/solver.dart';
import 'package:honest_solitaire/ui/board/board_semantics.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';

import '../../integration_test/support/spider_search.dart';

/// New Klondike as the script sets it: Draw 1, Standard, Untimed; a typed
/// number deals exactly that deal (Winnable deals only plays no part).
const a11yKlondikeOptions = KlondikeOptions(
  draw: DrawMode.one,
  scoring: ScoringMode.standard,
  timed: false,
);

/// New Spider as the script sets it: One suit, Strict, Untimed.
const a11ySpiderOptions = SpiderOptions(
  suits: SpiderSuits.one,
  relaxed: false,
  timed: false,
);

/// The solver's line from [deal] (default budget), cut at the first
/// position where FINISH is on offer; null when the solver finds no win.
List<Move>? klondikeToFinish(KlondikeGame deal) {
  final solved = solve(deal);
  if (solved is! Solved) return null;
  var g = deal;
  final line = <Move>[];
  for (final m in solved.moves) {
    if (canFinish(g)) break;
    final r = g.apply(m);
    if (r is! Applied<KlondikeGame>) return null;
    line.add(m);
    g = r.game;
  }
  return canFinish(g) ? line : null;
}

/// The beam search's winning line for [deal] (#112's search) of at most
/// [depth] moves, or null.
List<Move>? spiderToWin(SpiderGame deal, {int depth = 400}) =>
    beamSearch(deal, depth: depth);

/// How the owner makes one move with TalkBack: odd-numbered moves by
/// double-tap (the source, then the destination), even-numbered ones from
/// the source's actions menu.
sealed class TalkBackStep {
  const TalkBackStep(this.move, this.source, this.sourceIndex, this.said);

  final Move move;

  /// The node the owner focuses first, and its index in its pile (null for
  /// the pile node itself).
  final BoardPile source;
  final int? sourceIndex;

  /// What TalkBack announces once the move is made.
  final String said;

  /// The script's line for this step, numbered [n].
  String line(int n);
}

class DoubleTapStep extends TalkBackStep {
  const DoubleTapStep(
    super.move,
    super.source,
    super.sourceIndex,
    super.said, {
    required this.sourceLabel,
    this.target,
    this.targetIndex,
    this.targetLabel,
  });

  final String sourceLabel;

  /// The destination node; null for a stock tap, which is one double-tap.
  final BoardPile? target;
  final int? targetIndex;
  final String? targetLabel;

  @override
  String line(int n) => target == null
      ? '$n. Double-tap "$sourceLabel" — hear "$said"'
      : '$n. Double-tap "$sourceLabel", then "$targetLabel" — hear "$said"';
}

class ActionStep extends TalkBackStep {
  const ActionStep(
    super.move,
    super.source,
    super.sourceIndex,
    super.said, {
    required this.sourceLabel,
    required this.action,
  });

  final String sourceLabel;
  final String action;

  @override
  String line(int n) =>
      '$n. On "$sourceLabel", Actions → "$action" — hear "$said"';
}

/// Where [move] takes its cards from, as a board node: the pile and the
/// index of the first card moved (null for the stock).
(BoardPile, int?) sourceNode(Game g, Move move) => switch (move) {
  MoveRun(:final from, :final start) => (TableauPile(from), start),
  MoveCards(:final from, :final start) => (TableauPile(from), start),
  TableauToFoundation(:final from) => (
    TableauPile(from),
    _tableau(g)[from].length - 1,
  ),
  WasteToTableau() || WasteToFoundation() => (
    const WastePile(),
    (g as KlondikeGame).waste.length - 1,
  ),
  FoundationToTableau(:final foundation) => (
    FoundationPile(Suit.values[foundation]),
    (g as KlondikeGame).foundations[foundation].length - 1,
  ),
  Draw() || Recycle() || DealRow() => (const StockPile(), null),
  Flip() || MoveGroup() => throw ArgumentError('no source node for $move'),
};

/// Where [move] puts its cards, as the node the owner double-taps: a
/// column's top card (or the empty column), or the foundation pile.
(BoardPile, int?)? targetNode(Game g, Move move) {
  int? to = switch (move) {
    MoveRun(:final to) ||
    MoveCards(:final to) ||
    WasteToTableau(:final to) ||
    FoundationToTableau(:final to) => to,
    _ => null,
  };
  if (to != null) {
    final column = _tableau(g)[to];
    return (TableauPile(to), column.isEmpty ? null : column.length - 1);
  }
  final k = g is KlondikeGame ? g : null;
  return switch (move) {
    TableauToFoundation(:final from) => (
      FoundationPile(k!.tableau[from].last.suit),
      null,
    ),
    WasteToFoundation() => (FoundationPile(k!.waste.last.suit), null),
    _ => null,
  };
}

/// TalkBack's label for the node at [index] of [pile] (null: the pile's
/// own node).
String nodeLabel(Game g, BoardPile pile, int? index) {
  switch (pile) {
    case StockPile():
      return switch (g) {
        KlondikeGame k => stockLabel(k),
        SpiderGame s => spiderStockLabel(s),
      };
    case FoundationPile(:final suit):
      final cards = (g as KlondikeGame).foundations[suit.index];
      return index == null
          ? foundationLabel(suit, cards)
          : cardLabel(cards[index], pile, fromTop: cards.length - 1 - index);
    case WastePile():
      final k = g as KlondikeGame;
      return index == null
          ? wasteLabel(k)
          : cardLabel(
              k.waste[index],
              pile,
              fromTop: k.waste.length - 1 - index,
            );
    case TableauPile(:final column):
      final cards = _tableau(g)[column];
      if (index == null) return emptyColumnLabel(column);
      return cardLabel(cards[index], pile, fromTop: cards.length - 1 - index);
    case CompletedPile():
      return completedLabel(g as SpiderGame);
  }
}

/// The action label TalkBack lists for [move] on its source node.
String actionLabel(Game g, Move move) {
  final (pile, index) = sourceNode(g, move);
  final offered = pile is StockPile
      ? stockActions(g)
      : actionsFor(g, pile, index!);
  return offered.firstWhere((a) => a.move == move).label;
}

/// The script's step for [m] from [g] as move number [n]: odd numbers by
/// double-tap, even ones by the actions menu.
TalkBackStep stepFor(Game g, Move m, int n) {
  final r = g.apply(m);
  if (r is! Applied<Game>) throw StateError('a11y: move $n ($m) is refused');
  final said = describeStep(g, m, r.game);
  final (source, sourceIndex) = sourceNode(g, m);
  final sourceLabel = nodeLabel(g, source, sourceIndex);
  if (n.isOdd) {
    final target = targetNode(g, m);
    return DoubleTapStep(
      m,
      source,
      sourceIndex,
      said,
      sourceLabel: sourceLabel,
      target: target?.$1,
      targetIndex: target?.$2,
      targetLabel: target == null ? null : nodeLabel(g, target.$1, target.$2),
    );
  }
  return ActionStep(
    m,
    source,
    sourceIndex,
    said,
    sourceLabel: sourceLabel,
    action: actionLabel(g, m),
  );
}

/// The script's steps for [line] from [deal].
List<TalkBackStep> talkBackSteps(Game deal, List<Move> line) {
  final out = <TalkBackStep>[];
  var g = deal;
  for (final (i, m) in line.indexed) {
    out.add(stepFor(g, m, i + 1));
    g = (g.apply(m) as Applied<Game>).game;
  }
  return out;
}

/// The legal move from [g] whose step numbered [n] reads exactly [text],
/// or null when none does.
TalkBackStep? matchLine(Game g, String text, int n) {
  for (final m in g.legalMoves()) {
    if (m is Flip || m is MoveGroup) continue;
    final step = stepFor(g, m, n);
    if (step.line(n) == text) return step;
  }
  return null;
}

List<List<Card>> _tableau(Game g) => switch (g) {
  KlondikeGame k => k.tableau,
  SpiderGame s => s.tableau,
};
