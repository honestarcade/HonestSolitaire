part of 'game.dart';

/// One step back: the game as it was before [move] was applied.
///
/// Snapshots chain through their own [before], so a game holds only its last
/// entry and the history is the chain — sharing every unchanged pile, so a
/// thousand-move game stays small (#64).
class HistoryEntry {
  const HistoryEntry(this.before, this.move, this.effects);

  final Game before;
  final Move move;

  /// What [move] did, so an undo can animate the reversal.
  final Effects effects;
}

/// Several moves applied as one undo step: an auto-finish sweep (#67).
class MoveGroup extends Move {
  const MoveGroup(this.moves);

  final List<Move> moves;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'group',
    'moves': [for (final m in moves) m.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is MoveGroup && _sameMoves(other.moves, moves);

  @override
  int get hashCode => Object.hashAll(moves);
}

bool _sameMoves(List<Move> a, List<Move> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Every move applied since the deal, oldest first.
List<Move> _historyMoves(Game game) {
  final out = <Move>[];
  for (var e = game._previous; e != null; e = e.before._previous) {
    out.add(e.move);
  }
  return out.reversed.toList(growable: false);
}

/// The number of undo steps back to the deal.
int _historyLength(Game game) {
  var n = 0;
  for (var e = game._previous; e != null; e = e.before._previous) {
    n++;
  }
  return n;
}

/// Whether the Unlimited-undo setting lets [move] be undone when it is the
/// latest step: with the setting off, a draw, recycle or Spider row deal is
/// never undone (owner, /n8-plan M2 round one).
bool _limitedUndoAllows(Move move) => switch (move) {
  Draw() || Recycle() || DealRow() => false,
  _ => true,
};

/// The shared undo rule: nothing after a win; unlimited walks the whole
/// chain; limited undoes the latest move once, and only a kind the setting
/// allows.
bool _canUndo(Game game, {required bool unlimited}) {
  final entry = game._previous;
  if (entry == null || game.isWon) return false;
  if (unlimited) return true;
  return !game._lastUndone && _limitedUndoAllows(entry.move);
}
