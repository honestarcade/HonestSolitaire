/// Klondike's auto-finish (#67): once every tableau card is face up and the
/// rest can surely be swept to the foundations, `finishMoves` names the
/// sweep card by card, `canFinish`/`isSolved` say when to offer it, and
/// `applyFinish` applies it as one undo step.
///
/// FINISH never shows and then fails: `canFinish` is true only when
/// `finishMoves` really completes from here.
library;

import 'game.dart';
import 'hints.dart';
import 'solver.dart';

/// The budget the fallback search gets when the greedy sweep stalls. Small,
/// because an all-face-up board is a tiny search.
const int finishFallbackBudget = 5000;

/// Every tableau card is face up, the game is not yet won, and the sweep
/// completes. Memoised per game object: the game is immutable, so the answer
/// never changes.
bool canFinish(KlondikeGame game) {
  final memo = _canFinishMemo[game];
  if (memo != null) return memo;
  final result =
      !game.isWon && game.allTableauFaceUp && finishMoves(game).isNotEmpty;
  _canFinishMemo[game] = result;
  return result;
}

final Expando<bool> _canFinishMemo = Expando<bool>('canFinish');

/// The automatic trigger: [canFinish] with an empty stock and waste (owner,
/// /n8-plan M2 round one).
bool isSolved(KlondikeGame game) =>
    game.stock.isEmpty && game.waste.isEmpty && canFinish(game);

/// The ordered moves that finish [game], each legal from the state before
/// it, ending in `isWon`; empty when the board cannot be finished from here
/// (a face-down card, a won game, or a stock the draw mode cannot unlock).
///
/// Greedy: the lowest-rank foundation move first (ties by suit order,
/// tableau before waste), drawing or recycling only when a foundation card
/// is reachable in the stock, then waste→tableau and leftmost
/// tableau→tableau moves to unblock, never foundation→tableau; a visited set
/// stops loops, and when the greedy sweep stalls the solver finishes the
/// line with a small budget.
List<Move> finishMoves(KlondikeGame game) {
  if (game.isWon || !game.allTableauFaceUp) return const [];
  final moves = <Move>[];
  final visited = <String>{_pilesKey(game)};
  var g = game;
  for (var step = 0; step < 400; step++) {
    if (g.isWon) return List.unmodifiable(moves);

    final up = _lowestFoundationMove(g);
    if (up != null) {
      g = _step(g, up, moves);
      continue;
    }

    final draws = _drawsToFoundationCard(g);
    if (draws.isNotEmpty) {
      for (final d in draws) {
        g = _step(g, d, moves);
      }
      continue;
    }

    final unblock = _unblockMove(g, visited);
    if (unblock != null) {
      g = _step(g, unblock, moves);
      visited.add(_pilesKey(g));
      continue;
    }

    final solved = solve(
      g,
      nodeBudget: finishFallbackBudget,
      allowFoundationToTableau: false,
    );
    if (solved is Solved) {
      return List.unmodifiable([...moves, ...solved.moves]);
    }
    return const [];
  }
  final solved = solve(
    g,
    nodeBudget: finishFallbackBudget,
    allowFoundationToTableau: false,
  );
  if (solved is Solved) return List.unmodifiable([...moves, ...solved.moves]);
  return const [];
}

/// Applies the whole sweep as one history entry: `Applied(finalGame,
/// effects)` with the per-step effects in `effects.steps`, or
/// `Refused(cannotFinish)` when [canFinish] is false.
ApplyResult<KlondikeGame> applyFinish(KlondikeGame game) {
  if (!canFinish(game)) return const Refused(RefusalReason.cannotFinish);
  final result = game.applyAll(finishMoves(game));
  switch (result) {
    case Applied(:final game, :final effects):
      assert(game.isWon, 'canFinish was true but the sweep did not win');
      return Applied(game as KlondikeGame, effects);
    case Refused(:final reason):
      assert(false, 'a finish step was refused: $reason');
      return Refused(reason);
  }
}

KlondikeGame _step(KlondikeGame g, Move move, List<Move> moves) {
  final result = g.apply(move);
  if (result is! Applied<KlondikeGame>) {
    throw StateError('finish: $move refused as $result on\n$g');
  }
  moves.add(move);
  return result.game;
}

String _pilesKey(KlondikeGame g) =>
    '${g.tableau}|${g.stock}|${g.waste}|${g.foundations}';

/// The foundation move with the lowest card rank; ties by suit order, then
/// tableau before waste.
Move? _lowestFoundationMove(KlondikeGame g) {
  Move? best;
  var bestRank = 99;
  var bestSuit = 99;
  for (var c = 0; c < klondikeColumns; c++) {
    final column = g.tableau[c];
    if (column.isEmpty) continue;
    final card = column.last;
    if (!g.acceptsOnFoundation(card)) continue;
    if (card.rank < bestRank ||
        (card.rank == bestRank && card.suit.index < bestSuit)) {
      best = TableauToFoundation(c);
      bestRank = card.rank;
      bestSuit = card.suit.index;
    }
  }
  if (g.waste.isNotEmpty) {
    final card = g.waste.last;
    if (g.acceptsOnFoundation(card) &&
        (card.rank < bestRank ||
            (card.rank == bestRank && card.suit.index < bestSuit))) {
      best = const WasteToFoundation();
    }
  }
  return best;
}

/// The draws (and at most one recycle) that bring a foundation-playable card
/// to the top of the waste, or empty when a full pass has none.
List<Move> _drawsToFoundationCard(KlondikeGame game) {
  if (game.stock.isEmpty && game.waste.isEmpty) return const [];
  final moves = <Move>[];
  var g = game;
  var recycled = false;
  while (true) {
    if (g.stock.isEmpty) {
      if (recycled || g.waste.isEmpty) return const [];
      g = _apply(g, const Recycle());
      moves.add(const Recycle());
      recycled = true;
      continue;
    }
    g = _apply(g, const Draw());
    moves.add(const Draw());
    if (g.acceptsOnFoundation(g.waste.last)) return moves;
  }
}

/// A waste→tableau move, else the leftmost tableau→tableau run move, that
/// leads to a position not seen yet. Never a whole column onto an empty one.
Move? _unblockMove(KlondikeGame g, Set<String> visited) {
  final candidates = <Move>[];
  if (g.waste.isNotEmpty) {
    final dest = bestDestination(g, const PileRef.waste());
    if (dest is WasteToTableau) candidates.add(dest);
  }
  for (var c = 0; c < klondikeColumns; c++) {
    final column = g.tableau[c];
    if (column.isEmpty) continue;
    for (
      var start = KlondikeGame.runBase(column);
      start < column.length;
      start++
    ) {
      for (var d = 0; d < klondikeColumns; d++) {
        if (d == c) continue;
        if (start == 0 && g.tableau[d].isEmpty) continue;
        if (g.acceptsOnTableau(d, column[start])) {
          candidates.add(MoveRun(c, start, d));
        }
      }
    }
  }
  for (final move in candidates) {
    final result = g.apply(move);
    if (result is Applied<KlondikeGame> &&
        !visited.contains(_pilesKey(result.game))) {
      return move;
    }
  }
  return null;
}

KlondikeGame _apply(KlondikeGame g, Move move) {
  final result = g.apply(move);
  if (result is! Applied<KlondikeGame>) {
    throw StateError('finish: $move refused as $result on\n$g');
  }
  return result.game;
}
