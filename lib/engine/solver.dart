/// A Klondike solver bounded by work, not time (#66).
///
/// `solve` searches depth-first over a compact copy of the position, with
/// safe foundation moves made automatically, stock draws collapsed into
/// "draw until this card is on top" macros, and a transposition set keyed on
/// the full canonical position so the same state is never expanded twice.
/// Nothing is pruned that could lose a solution, so a search that runs out
/// of states is `Unsolvable`; one that runs out of budget is `Unknown`.
///
/// Every `Solved` line is replayed through `KlondikeGame.apply` before it is
/// returned — the solver's word is never taken for the engine's.
library;

import 'card.dart';
import 'game.dart';

/// The outcome of `solve`.
sealed class SolveResult {
  const SolveResult();
}

/// A complete line from the given position to `isWon`, already replayed.
class Solved extends SolveResult {
  const Solved(this.moves, this.nodesUsed);

  /// Klondike moves, plus `Flip`s where the game has auto-flip off.
  final List<Move> moves;
  final int nodesUsed;

  @override
  String toString() => 'Solved(${moves.length} moves, $nodesUsed nodes)';
}

/// The budget ran out before a line was found or the space exhausted.
class Unknown extends SolveResult {
  const Unknown(this.nodesUsed);

  final int nodesUsed;

  @override
  String toString() => 'Unknown($nodesUsed nodes)';
}

/// Every reachable position was expanded and none wins.
class Unsolvable extends SolveResult {
  const Unsolvable(this.nodesUsed);

  final int nodesUsed;

  @override
  String toString() => 'Unsolvable($nodesUsed nodes)';
}

/// The budget the winnable dealer and the floors test use. Chosen by
/// measurement against #66's floors; the completion comment on #66 records
/// the run.
const int defaultNodeBudget = 40000;

/// Searches from [game] with at most [nodeBudget] expanded states.
SolveResult solve(KlondikeGame game, {int nodeBudget = defaultNodeBudget}) {
  if (nodeBudget <= 0) {
    throw ArgumentError.value(nodeBudget, 'nodeBudget', 'must be > 0');
  }
  if (game.isWon) return const Solved([], 0);
  return _Search(game, nodeBudget).run();
}

// ---------------------------------------------------------------- compact

int _id(Card card) => card.suit.index * 13 + (card.rank - 1);
int _rank(int id) => id % 13 + 1;
int _suit(int id) => id ~/ 13;
bool _red(int id) {
  final s = _suit(id);
  return s == 1 || s == 2;
}

/// An immutable compact position. Columns hold card ids bottom to top with
/// the number of face-down cards at the bottom; stock and waste hold ids
/// with the top last; foundations hold the top rank per suit.
class _State {
  _State(this.columns, this.down, this.stock, this.waste, this.foundation);

  // Not final: a fresh copy is built by `_Search._copyState`, which shares
  // every list with its parent, and the transition that changes a pile
  // replaces that one list before touching it. A state is never changed
  // once it has been handed to a frame.
  List<List<int>> columns;
  List<int> down;
  List<int> stock;
  List<int> waste;
  List<int> foundation;

  bool get won =>
      foundation[0] == 13 &&
      foundation[1] == 13 &&
      foundation[2] == 13 &&
      foundation[3] == 13;

  /// The full position as text. Columns are sorted because Klondike is
  /// symmetric under any permutation of them: a line from one arrangement
  /// maps to the other by renaming columns.
  String key() {
    // One character per card (id + 1), 0 as the separator, and the
    // face-down count as a character of its own; cheaper than digits.
    final cols = <String>[];
    for (var c = 0; c < 7; c++) {
      final codes = <int>[down[c] + 100, ...columns[c].map((id) => id + 1)];
      cols.add(String.fromCharCodes(codes));
    }
    cols.sort();
    final codes = <int>[];
    for (final col in cols) {
      codes.addAll(col.codeUnits);
      codes.add(0);
    }
    codes.add(200);
    for (final id in stock) {
      codes.add(id + 1);
    }
    codes.add(0);
    for (final id in waste) {
      codes.add(id + 1);
    }
    codes.add(0);
    for (final f in foundation) {
      codes.add(f + 1);
    }
    return String.fromCharCodes(codes);
  }

  static _State of(KlondikeGame game) {
    final columns = <List<int>>[];
    final down = <int>[];
    for (final column in game.tableau) {
      columns.add([for (final card in column) _id(card)]);
      var n = 0;
      for (final card in column) {
        if (!card.faceUp) {
          n++;
        } else {
          break;
        }
      }
      // The top card is always known to the search: a face-down top (only
      // possible with auto-flip off) is flipped first during the replay.
      if (n == column.length && n > 0) n--;
      down.add(n);
    }
    return _State(
      columns,
      down,
      [for (final card in game.stock) _id(card)],
      [for (final card in game.waste) _id(card)],
      [for (final f in game.foundations) f.length],
    );
  }
}

/// A move in compact space, with the engine moves it stands for.
class _Edge {
  _Edge(this.next, this.moves);

  final _State next;
  final List<KlondikeMove> moves;
}

class _Frame {
  _Frame(this.state, this.edges);

  final _State state;
  final List<_Edge> edges;
  int index = 0;
}

class _Search {
  _Search(this.game, this.budget) : drawCount = game.options.draw.count;

  final KlondikeGame game;
  final int budget;
  final int drawCount;
  final Set<String> visited = {};
  int nodes = 0;

  SolveResult run() {
    final start = _autoFoundation(_State.of(game));
    if (start.next.won) return _finish(start.moves);
    visited.add(start.next.key());
    nodes = 1;
    final path = <_Edge>[start];
    final stack = <_Frame>[_Frame(start.next, _edges(start.next))];

    while (stack.isNotEmpty) {
      final frame = stack.last;
      if (frame.index >= frame.edges.length) {
        stack.removeLast();
        if (path.length > 1) path.removeLast();
        continue;
      }
      final edge = frame.edges[frame.index++];
      if (edge.next.won) {
        return _finish([for (final e in path) ...e.moves, ...edge.moves]);
      }
      final key = edge.next.key();
      if (!visited.add(key)) continue;
      nodes++;
      if (nodes > budget) return Unknown(nodes);
      path.add(edge);
      stack.add(_Frame(edge.next, _edges(edge.next)));
    }
    return Unsolvable(nodes);
  }

  /// Replays [moves] through the engine, inserting `Flip`s where the game
  /// has auto-flip off, and returns `Solved` only if the engine agrees.
  SolveResult _finish(List<KlondikeMove> moves) {
    var g = game;
    final line = <Move>[];
    // A face-down top in the starting position (auto-flip off) is turned
    // first: the search treats every top card as known.
    if (!g.options.autoFlip) {
      final flipped = _flipTops(g, line);
      if (flipped == null) return Unknown(nodes);
      g = flipped;
    }
    for (final move in moves) {
      final result = g.apply(move);
      if (result is! Applied<KlondikeGame>) return Unknown(nodes);
      g = result.game;
      line.add(move);
      if (!g.options.autoFlip) {
        final flipped = _flipTops(g, line);
        if (flipped == null) return Unknown(nodes);
        g = flipped;
      }
    }
    if (!g.isWon) return Unknown(nodes);
    return Solved(List.unmodifiable(line), nodes);
  }

  /// Flips every face-down top card of [g] by hand, appending the moves to
  /// [line]; null if the engine refuses one.
  KlondikeGame? _flipTops(KlondikeGame g, List<Move> line) {
    for (var c = 0; c < klondikeColumns; c++) {
      final column = g.tableau[c];
      if (column.isNotEmpty && !column.last.faceUp) {
        final flipped = g.apply(Flip(c));
        if (flipped is! Applied<KlondikeGame>) return null;
        g = flipped.game;
        line.add(Flip(c));
      }
    }
    return g;
  }

  // --------------------------------------------------------------- rules

  bool _safeToFoundation(_State s, int id) {
    final rank = _rank(id);
    if (s.foundation[_suit(id)] != rank - 1) return false;
    if (rank <= 2) return true;
    final red = _red(id);
    // Opposite-colour foundations: spades(0)/clubs(3) are black,
    // hearts(1)/diamonds(2) are red.
    final a = red ? s.foundation[0] : s.foundation[1];
    final b = red ? s.foundation[3] : s.foundation[2];
    final lower = a < b ? a : b;
    return rank <= lower + 1;
  }

  bool _foundationAccepts(_State s, int id) =>
      s.foundation[_suit(id)] == _rank(id) - 1;

  bool _columnAccepts(_State s, int c, int id) {
    final column = s.columns[c];
    if (column.isEmpty) return _rank(id) == 13;
    if (column.length <= s.down[c]) return false;
    final top = column.last;
    return _rank(top) == _rank(id) + 1 && _red(top) != _red(id);
  }

  /// The lowest index from which column [c]'s top run is valid.
  int _runBase(_State s, int c) {
    final column = s.columns[c];
    if (column.length <= s.down[c]) return column.length;
    var base = column.length - 1;
    while (base > s.down[c] &&
        _rank(column[base - 1]) == _rank(column[base]) + 1 &&
        _red(column[base - 1]) != _red(column[base])) {
      base--;
    }
    return base;
  }

  // ---------------------------------------------------------- transitions

  /// A copy sharing every pile list with [s]; piles are replaced, never
  /// changed in place (see `_State`).
  _State _copyState(_State s) => _State(
    List<List<int>>.of(s.columns),
    s.down,
    s.stock,
    s.waste,
    s.foundation,
  );

  /// Removes the top cards of column [c] from [start] on, turning up the
  /// exposed card (auto-flip is forced on inside the search).
  void _takeFrom(_State s, int c, int start) {
    s.columns[c] = s.columns[c].sublist(0, start);
    if (s.columns[c].length == s.down[c] && s.down[c] > 0) {
      s.down = List<int>.of(s.down);
      s.down[c]--;
    }
  }

  void _addToColumn(_State s, int d, Iterable<int> ids) {
    s.columns[d] = [...s.columns[d], ...ids];
  }

  void _popWaste(_State s) {
    s.waste = s.waste.sublist(0, s.waste.length - 1);
  }

  void _foundationUp(_State s, int suit, int delta) {
    s.foundation = List<int>.of(s.foundation);
    s.foundation[suit] += delta;
  }

  /// Makes every safe foundation move, repeating until none is left.
  _Edge _autoFoundation(_State input) {
    var s = input;
    final moves = <KlondikeMove>[];
    var copied = false;
    var again = true;
    while (again) {
      again = false;
      if (s.waste.isNotEmpty && _safeToFoundation(s, s.waste.last)) {
        if (!copied) {
          s = _copyState(s);
          copied = true;
        }
        final id = s.waste.last;
        _popWaste(s);
        _foundationUp(s, _suit(id), 1);
        moves.add(const WasteToFoundation());
        again = true;
        continue;
      }
      for (var c = 0; c < 7; c++) {
        final column = s.columns[c];
        if (column.isEmpty || column.length <= s.down[c]) continue;
        final id = column.last;
        if (_safeToFoundation(s, id)) {
          if (!copied) {
            s = _copyState(s);
            copied = true;
          }
          _takeFrom(s, c, column.length - 1);
          _foundationUp(s, _suit(id), 1);
          moves.add(TableauToFoundation(c));
          again = true;
          break;
        }
      }
    }
    return _Edge(s, moves);
  }

  _Edge _withAuto(_State s, List<KlondikeMove> moves) {
    final auto = _autoFoundation(s);
    return _Edge(
      auto.next,
      auto.moves.isEmpty ? moves : [...moves, ...auto.moves],
    );
  }

  /// The ordered edges from [s]: foundation moves, run moves that turn up a
  /// card (most face-down first), waste to tableau, stock macros (fewest
  /// draws first), run moves that empty a column, partial runs, and finally
  /// cards taken back off a foundation.
  List<_Edge> _edges(_State s) {
    final first = <_Edge>[];
    final uncover = <(int, _Edge)>[];
    final wasteMoves = <_Edge>[];
    final emptying = <_Edge>[];
    final partial = <_Edge>[];
    final fromFoundation = <_Edge>[];

    // Non-safe foundation moves.
    if (s.waste.isNotEmpty && _foundationAccepts(s, s.waste.last)) {
      final n = _copyState(s);
      final id = n.waste.last;
      _popWaste(n);
      _foundationUp(n, _suit(id), 1);
      first.add(_withAuto(n, const [WasteToFoundation()]));
    }
    for (var c = 0; c < 7; c++) {
      final column = s.columns[c];
      if (column.isEmpty || column.length <= s.down[c]) continue;
      if (_foundationAccepts(s, column.last)) {
        final n = _copyState(s);
        _takeFrom(n, c, column.length - 1);
        _foundationUp(n, _suit(column.last), 1);
        first.add(_withAuto(n, [TableauToFoundation(c)]));
      }
    }

    // Run moves.
    for (var c = 0; c < 7; c++) {
      final column = s.columns[c];
      if (column.isEmpty || column.length <= s.down[c]) continue;
      final base = _runBase(s, c);
      for (var start = base; start < column.length; start++) {
        final head = column[start];
        final wholeRun = start == base;
        for (var d = 0; d < 7; d++) {
          if (d == c || !_columnAccepts(s, d, head)) continue;
          final targetEmpty = s.columns[d].isEmpty;
          // A whole column onto an empty column is the same position.
          if (targetEmpty && start == 0) continue;
          final n = _copyState(s);
          _addToColumn(n, d, column.sublist(start));
          _takeFrom(n, c, start);
          final edge = _withAuto(n, [MoveRun(c, start, d)]);
          if (!wholeRun) {
            partial.add(edge);
          } else if (start == s.down[c] && s.down[c] > 0) {
            uncover.add((s.down[c], edge));
          } else if (start == 0) {
            emptying.add(edge);
          } else {
            // A whole run sitting on a face-up parent: only useful if the
            // parent can then move; ranked with partial runs.
            partial.add(edge);
          }
          if (targetEmpty) break; // one empty column is like any other
        }
      }
    }

    // Waste to tableau.
    if (s.waste.isNotEmpty) {
      final id = s.waste.last;
      for (var d = 0; d < 7; d++) {
        if (!_columnAccepts(s, d, id)) continue;
        final n = _copyState(s);
        _popWaste(n);
        _addToColumn(n, d, [id]);
        wasteMoves.add(_withAuto(n, [WasteToTableau(d)]));
        if (s.columns[d].isEmpty) break;
      }
    }

    // Stock macros.
    final stockEdges = _stockEdges(s);

    // Foundation to tableau.
    for (var f = 0; f < 4; f++) {
      final rank = s.foundation[f];
      if (rank == 0) continue;
      final id = f * 13 + rank - 1;
      for (var d = 0; d < 7; d++) {
        if (!_columnAccepts(s, d, id)) continue;
        final n = _copyState(s);
        _foundationUp(n, f, -1);
        _addToColumn(n, d, [id]);
        fromFoundation.add(_Edge(n, [FoundationToTableau(f, d)]));
        if (s.columns[d].isEmpty) break;
      }
    }

    uncover.sort((a, b) => b.$1.compareTo(a.$1));
    return [
      ...first,
      for (final u in uncover) u.$2,
      ...wasteMoves,
      ...stockEdges,
      ...emptying,
      ...partial,
      ...fromFoundation,
    ];
  }

  /// "Draw until this card is on top" for every reachable waste top that can
  /// then be played, through at most one recycle. Draw 3 is respected: the
  /// simulation draws exactly as the game would.
  List<_Edge> _stockEdges(_State s) {
    final out = <_Edge>[];
    if (s.stock.isEmpty && s.waste.isEmpty) return out;
    var stock = List<int>.of(s.stock);
    var waste = List<int>.of(s.waste);
    final moves = <KlondikeMove>[];
    var recycled = false;
    final seenTops = <int>{};
    while (true) {
      if (stock.isEmpty) {
        if (recycled || waste.isEmpty) break;
        stock = waste.reversed.toList();
        waste = [];
        moves.add(const Recycle());
        recycled = true;
        continue;
      }
      final n = stock.length < drawCount ? stock.length : drawCount;
      for (var i = 0; i < n; i++) {
        waste.add(stock.removeLast());
      }
      moves.add(const Draw());
      final top = waste.last;
      if (!seenTops.add(top)) continue;
      var playable = _foundationAccepts(s, top);
      if (!playable) {
        for (var d = 0; d < 7 && !playable; d++) {
          playable = _columnAccepts(s, d, top);
        }
      }
      if (!playable) continue;
      out.add(
        _withAuto(
          _State(
            s.columns,
            s.down,
            List<int>.of(stock),
            List<int>.of(waste),
            s.foundation,
          ),
          List<KlondikeMove>.of(moves),
        ),
      );
    }
    return out;
  }
}
