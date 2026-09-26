/// Hints and one-tap destinations for both games (#65).
///
/// `bestDestination` is where a tapped card goes; `hint` names the most
/// useful move by the design's priorities, or says honestly that nothing
/// useful is left. A hint's destination is always `bestDestination` of its
/// source, so there is one ranking path.
library;

import 'card.dart';
import 'game.dart';

/// Which pile a tap or drag started from.
enum PileRefKind { tableau, waste, foundation, stock }

/// A pile, and for a tableau column the index of the tapped card.
class PileRef {
  const PileRef(this.kind, this.index, this.cardIndex);

  const PileRef.tableau(int column, int cardIndex)
    : this(PileRefKind.tableau, column, cardIndex);

  const PileRef.waste() : this(PileRefKind.waste, 0, 0);

  const PileRef.foundation(int index) : this(PileRefKind.foundation, index, 0);

  const PileRef.stock() : this(PileRefKind.stock, 0, 0);

  final PileRefKind kind;
  final int index;
  final int cardIndex;

  @override
  bool operator ==(Object other) =>
      other is PileRef &&
      other.kind == kind &&
      other.index == index &&
      other.cardIndex == cardIndex;

  @override
  int get hashCode => Object.hash(kind, index, cardIndex);

  @override
  String toString() => 'PileRef(${kind.name}, $index, $cardIndex)';
}

/// The result of asking for a hint.
sealed class Hint {
  const Hint();
}

class MoveHint extends Hint {
  const MoveHint(this.move);

  final Move move;

  @override
  bool operator ==(Object other) => other is MoveHint && other.move == move;

  @override
  int get hashCode => move.hashCode;

  @override
  String toString() => 'MoveHint($move)';
}

/// No useful card move exists and the stock cannot help. The UI offers Undo
/// and New deal; the game is not ended (owner, /n8-plan M2 round one).
class NoMovesLeft extends Hint {
  const NoMovesLeft();

  @override
  bool operator ==(Object other) => other is NoMovesLeft;

  @override
  int get hashCode => (NoMovesLeft).hashCode;

  @override
  String toString() => 'NoMovesLeft()';
}

/// The most useful move, or [NoMovesLeft].
Hint hint(Game game) => switch (game) {
  KlondikeGame k => klondikeHint(k),
  SpiderGame s => spiderHint(s),
};

/// Where a tapped card or run goes, or null when nothing accepts it (or the
/// source is invalid, face down, the stock, an empty pile, or a foundation
/// card — taking a card back off a foundation needs select-then-tap or a
/// drag).
Move? bestDestination(Game game, PileRef source) => switch (game) {
  KlondikeGame k => klondikeBestDestination(k, source),
  SpiderGame s => spiderBestDestination(s, source),
};

// ------------------------------------------------------------------ Klondike

Move? klondikeBestDestination(KlondikeGame game, PileRef source) {
  if (game.isWon) return null;
  switch (source.kind) {
    case PileRefKind.stock:
    case PileRefKind.foundation:
      return null;
    case PileRefKind.waste:
      if (game.waste.isEmpty) return null;
      final card = game.waste.last;
      if (game.acceptsOnFoundation(card)) return const WasteToFoundation();
      for (var d = 0; d < klondikeColumns; d++) {
        if (game.acceptsOnTableau(d, card)) return WasteToTableau(d);
      }
      return null;
    case PileRefKind.tableau:
      final c = source.index;
      if (c < 0 || c >= klondikeColumns) return null;
      final column = game.tableau[c];
      final i = source.cardIndex;
      if (i < 0 || i >= column.length) return null;
      if (!KlondikeGame.isAlternatingRun(column, i)) return null;
      final card = column[i];
      if (i == column.length - 1 && game.acceptsOnFoundation(card)) {
        return TableauToFoundation(c);
      }
      for (var d = 0; d < klondikeColumns; d++) {
        if (d == c) continue;
        // A run that already starts an otherwise empty column gains nothing
        // from another empty column.
        if (i == 0 && game.tableau[d].isEmpty) continue;
        if (game.acceptsOnTableau(d, card)) return MoveRun(c, i, d);
      }
      return null;
  }
}

class _Ranked {
  _Ranked(this.move, this.tier, this.key, this.order);

  final Move move;
  final int tier;

  /// Lower is better within a tier.
  final int key;

  /// Source order: waste first, then column index.
  final int order;

  bool beats(_Ranked? other) {
    if (other == null) return true;
    if (tier != other.tier) return tier < other.tier;
    if (key != other.key) return key < other.key;
    return order < other.order;
  }
}

int _faceDownCount(List<Card> column) {
  var n = 0;
  for (final card in column) {
    if (!card.faceUp) n++;
  }
  return n;
}

/// Whether a king is available to fill an empty column: the waste's top, or
/// a face-up king heading a run above a non-empty base.
bool _kingAvailable(KlondikeGame game) {
  if (game.waste.isNotEmpty && game.waste.last.isKing) return true;
  for (final column in game.tableau) {
    final base = KlondikeGame.runBase(column);
    if (base > 0 && base < column.length && column[base].isKing) return true;
  }
  return false;
}

/// Klondike's ranking: foundation moves; a flip (auto-flip off); a move that
/// turns up a face-down card (most face-down cards first); waste→tableau; a
/// king to an empty column that uncovers a card, or a move that empties a
/// column when a king is available; other non-pointless moves; then the
/// stock, only when a full pass can play something.
Hint klondikeHint(KlondikeGame game) {
  if (game.isWon) return const NoMovesLeft();

  if (game.waste.isNotEmpty && game.acceptsOnFoundation(game.waste.last)) {
    return const MoveHint(WasteToFoundation());
  }
  for (var c = 0; c < klondikeColumns; c++) {
    final column = game.tableau[c];
    if (column.isNotEmpty &&
        column.last.faceUp &&
        game.acceptsOnFoundation(column.last)) {
      return MoveHint(TableauToFoundation(c));
    }
  }
  if (!game.options.autoFlip) {
    for (var c = 0; c < klondikeColumns; c++) {
      final column = game.tableau[c];
      if (column.isNotEmpty && !column.last.faceUp) return MoveHint(Flip(c));
    }
  }

  const tierTurnsUp = 2;
  const tierWaste = 3;
  const tierKingOrEmpty = 4;
  const tierOther = 5;

  _Ranked? best;
  void consider(_Ranked candidate) {
    if (candidate.beats(best)) best = candidate;
  }

  if (game.waste.isNotEmpty) {
    final dest = klondikeBestDestination(game, const PileRef.waste());
    if (dest is WasteToTableau) consider(_Ranked(dest, tierWaste, 0, -1));
  }

  final kingAvailable = _kingAvailable(game);
  for (var c = 0; c < klondikeColumns; c++) {
    final column = game.tableau[c];
    if (column.isEmpty) continue;
    for (var i = KlondikeGame.runBase(column); i < column.length; i++) {
      final dest = klondikeBestDestination(game, PileRef.tableau(c, i));
      if (dest is! MoveRun) continue;
      final exposed = i > 0 ? column[i - 1] : null;
      if (exposed != null && !exposed.faceUp) {
        consider(_Ranked(dest, tierTurnsUp, -_faceDownCount(column), c));
      } else if (exposed != null) {
        // The run already sits on a valid parent; moving it is pointless
        // unless the card it exposes can then go to a foundation.
        if (game.acceptsOnFoundation(exposed)) {
          final toEmpty = game.tableau[dest.to].isEmpty;
          consider(_Ranked(dest, toEmpty ? tierKingOrEmpty : tierOther, 0, c));
        }
      } else if (kingAvailable) {
        consider(_Ranked(dest, tierKingOrEmpty, 0, c));
      } else {
        consider(_Ranked(dest, tierOther, 0, c));
      }
    }
  }
  if (best != null) return MoveHint(best!.move);

  if (stockCanHelp(game)) {
    return MoveHint(game.stock.isNotEmpty ? const Draw() : const Recycle());
  }
  return const NoMovesLeft();
}

/// Whether drawing (through at most one recycle) turns up a waste card that
/// can be played, with the tableau and foundations as they are. Draw 3 is
/// respected: the simulation draws exactly as the game would.
bool stockCanHelp(KlondikeGame game) {
  if (game.stock.isEmpty && game.waste.isEmpty) return false;
  var g = game;
  var recycled = false;
  while (true) {
    if (g.stock.isEmpty) {
      if (recycled || g.waste.isEmpty) return false;
      final r = g.apply(const Recycle());
      if (r is! Applied<KlondikeGame>) return false;
      g = r.game;
      recycled = true;
      continue;
    }
    final r = g.apply(const Draw());
    if (r is! Applied<KlondikeGame>) return false;
    g = r.game;
    if (klondikeBestDestination(g, const PileRef.waste()) != null) return true;
  }
}

// -------------------------------------------------------------------- Spider

Move? spiderBestDestination(SpiderGame game, PileRef source) {
  if (game.isWon || source.kind != PileRefKind.tableau) return null;
  final c = source.index;
  if (c < 0 || c >= spiderColumns) return null;
  final column = game.tableau[c];
  final i = source.cardIndex;
  if (i < 0 || i >= column.length) return null;
  if (!SpiderGame.isSameSuitRun(column, i)) return null;
  final card = column[i];
  final parent = i > 0 ? column[i - 1] : null;
  final onSameSuitParent =
      parent != null &&
      parent.faceUp &&
      parent.suit == card.suit &&
      parent.rank == card.rank + 1;

  int? sameSuit;
  int? anySuit;
  int? empty;
  for (var d = 0; d < spiderColumns; d++) {
    if (d == c) continue;
    final target = game.tableau[d];
    if (target.isEmpty) {
      empty ??= d;
      continue;
    }
    final top = target.last;
    if (!top.faceUp || top.rank != card.rank + 1) continue;
    if (top.suit == card.suit) {
      sameSuit ??= d;
    } else {
      anySuit ??= d;
    }
  }
  if (sameSuit != null) return MoveCards(c, i, sameSuit);
  // A run on a same-suit parent is never sent to a different-suit one; it
  // may still go to an empty column.
  if (anySuit != null && !onSameSuitParent) return MoveCards(c, i, anySuit);
  // A run that already fills a column from the top gains nothing from
  // another empty column.
  if (empty != null && i > 0) return MoveCards(c, i, empty);
  return null;
}

/// Whether [card], once exposed, could join a same-suit parent in a column
/// other than [except].
bool _hasSameSuitParent(SpiderGame game, Card card, int except) {
  for (var d = 0; d < spiderColumns; d++) {
    if (d == except) continue;
    final target = game.tableau[d];
    if (target.isEmpty) continue;
    final top = target.last;
    if (top.faceUp && top.suit == card.suit && top.rank == card.rank + 1) {
      return true;
    }
  }
  return false;
}

/// Spider's ranking: a flip (auto-flip off); a same-suit join; a move that
/// turns up a face-down card; a move into an empty column that uncovers a
/// card; other non-pointless moves; then dealing a row — or, under the
/// strict rule with an empty column and stock left, a card to fill the
/// column so the deal becomes legal again.
Hint spiderHint(SpiderGame game) {
  if (game.isWon) return const NoMovesLeft();

  if (!game.options.autoFlip) {
    for (var c = 0; c < spiderColumns; c++) {
      final column = game.tableau[c];
      if (column.isNotEmpty && !column.last.faceUp) return MoveHint(Flip(c));
    }
  }

  const tierJoin = 1;
  const tierTurnsUp = 2;
  const tierEmptyUncovers = 3;
  const tierOther = 4;

  _Ranked? best;
  void consider(_Ranked candidate) {
    if (candidate.beats(best)) best = candidate;
  }

  // Fill candidates for the strict rule, gathered in the same pass.
  _Ranked? fill;
  void considerFill(_Ranked candidate) {
    if (candidate.beats(fill)) fill = candidate;
  }

  for (var c = 0; c < spiderColumns; c++) {
    final column = game.tableau[c];
    if (column.isEmpty) continue;
    for (var i = SpiderGame.runBase(column); i < column.length; i++) {
      final dest = spiderBestDestination(game, PileRef.tableau(c, i));
      if (dest is! MoveCards) continue;
      final card = column[i];
      final runLength = column.length - i;
      final target = game.tableau[dest.to];
      final exposed = i > 0 ? column[i - 1] : null;
      final turnsUp = exposed != null && !exposed.faceUp;
      final exposesUseful =
          exposed != null &&
          exposed.faceUp &&
          _hasSameSuitParent(game, exposed, c);
      final onParent =
          exposed != null && exposed.faceUp && exposed.rank == card.rank + 1;
      final onSameSuitParent = onParent && exposed.suit == card.suit;
      final uncovers = turnsUp || exposesUseful;

      if (target.isNotEmpty && target.last.suit == card.suit) {
        // A same-suit join — unless the run already has one and the move
        // uncovers nothing.
        if (onSameSuitParent && !uncovers) continue;
        consider(_Ranked(dest, tierJoin, -runLength, c));
      } else if (target.isNotEmpty) {
        if (turnsUp) {
          consider(_Ranked(dest, tierTurnsUp, -_faceDownCount(column), c));
        } else if (onParent && !exposesUseful) {
          continue; // one different-suit parent to another: pointless
        } else {
          consider(_Ranked(dest, tierOther, -runLength, c));
        }
      } else {
        // Into an empty column (bestDestination never sends a whole column).
        if (turnsUp) {
          consider(
            _Ranked(dest, tierEmptyUncovers, -_faceDownCount(column), c),
          );
        } else if (exposesUseful) {
          consider(_Ranked(dest, tierEmptyUncovers, 0, c));
        } else {
          considerFill(_Ranked(dest, 0, runLength, c));
        }
      }
    }
  }
  if (best != null) return MoveHint(best!.move);

  if (game.canDealRow) return const MoveHint(DealRow());
  if (!game.options.relaxed && game.hasEmptyColumn && game.stock.isNotEmpty) {
    if (fill != null) return MoveHint(fill!.move);
  }
  return const NoMovesLeft();
}
