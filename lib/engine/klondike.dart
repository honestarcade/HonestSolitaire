part of 'game.dart';

/// How many cards a stock tap turns onto the waste.
enum DrawMode {
  one(1),
  three(3);

  const DrawMode(this.count);

  final int count;
}

/// A Klondike game's options, fixed at the deal (#60, #62).
class KlondikeOptions {
  const KlondikeOptions({
    this.draw = DrawMode.one,
    this.scoring = ScoringMode.standard,
    this.autoFlip = true,
    this.timed = true,
  });

  final DrawMode draw;
  final ScoringMode scoring;

  /// Turn an uncovered tableau card face up at once. Off, `Flip` is a move.
  final bool autoFlip;

  /// The New Klondike screen's Timed/Untimed choice: whether the clock
  /// changes the score. The clock runs either way (Statistics counts it).
  final bool timed;

  KlondikeOptions copyWith({
    DrawMode? draw,
    ScoringMode? scoring,
    bool? autoFlip,
    bool? timed,
  }) => KlondikeOptions(
    draw: draw ?? this.draw,
    scoring: scoring ?? this.scoring,
    autoFlip: autoFlip ?? this.autoFlip,
    timed: timed ?? this.timed,
  );

  Map<String, Object?> toJson() => {
    'draw': draw.count,
    'scoring': scoring.name,
    'autoFlip': autoFlip,
    'timed': timed,
  };

  @override
  bool operator ==(Object other) =>
      other is KlondikeOptions &&
      other.draw == draw &&
      other.scoring == scoring &&
      other.autoFlip == autoFlip &&
      other.timed == timed;

  @override
  int get hashCode => Object.hash(draw, scoring, autoFlip, timed);

  @override
  String toString() =>
      'KlondikeOptions(draw ${draw.count}, ${scoring.name}, '
      'autoFlip $autoFlip, timed $timed)';
}

/// A Klondike move. One subtype per kind; a to-foundation move names no
/// slot because the card's suit picks it.
sealed class KlondikeMove extends Move {
  const KlondikeMove();
}

/// A face-up run from [start] in column [from] onto column [to].
class MoveRun extends KlondikeMove {
  const MoveRun(this.from, this.start, this.to);

  final int from;
  final int start;
  final int to;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'run',
    'from': from,
    'start': start,
    'to': to,
  };

  @override
  bool operator ==(Object other) =>
      other is MoveRun &&
      other.from == from &&
      other.start == start &&
      other.to == to;

  @override
  int get hashCode => Object.hash(MoveRun, from, start, to);

  @override
  String toString() => 'MoveRun($from[$start] → $to)';
}

/// The waste's top card onto column [to].
class WasteToTableau extends KlondikeMove {
  const WasteToTableau(this.to);

  final int to;

  @override
  Map<String, Object?> toJson() => {'kind': 'wasteToTableau', 'to': to};

  @override
  bool operator ==(Object other) => other is WasteToTableau && other.to == to;

  @override
  int get hashCode => Object.hash(WasteToTableau, to);

  @override
  String toString() => 'WasteToTableau($to)';
}

/// The waste's top card onto its suit's foundation.
class WasteToFoundation extends KlondikeMove {
  const WasteToFoundation();

  @override
  Map<String, Object?> toJson() => const {'kind': 'wasteToFoundation'};

  @override
  bool operator ==(Object other) => other is WasteToFoundation;

  @override
  int get hashCode => (WasteToFoundation).hashCode;

  @override
  String toString() => 'WasteToFoundation()';
}

/// Column [from]'s top card onto its suit's foundation.
class TableauToFoundation extends KlondikeMove {
  const TableauToFoundation(this.from);

  final int from;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'tableauToFoundation',
    'from': from,
  };

  @override
  bool operator ==(Object other) =>
      other is TableauToFoundation && other.from == from;

  @override
  int get hashCode => Object.hash(TableauToFoundation, from);

  @override
  String toString() => 'TableauToFoundation($from)';
}

/// The top card of foundation [foundation] (0..3, in `Suit` order) back onto
/// column [to]. Allowed (owner, /n8-plan M2 round one).
class FoundationToTableau extends KlondikeMove {
  const FoundationToTableau(this.foundation, this.to);

  final int foundation;
  final int to;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'foundationToTableau',
    'foundation': foundation,
    'to': to,
  };

  @override
  bool operator ==(Object other) =>
      other is FoundationToTableau &&
      other.foundation == foundation &&
      other.to == to;

  @override
  int get hashCode => Object.hash(FoundationToTableau, foundation, to);

  @override
  String toString() => 'FoundationToTableau($foundation → $to)';
}

/// Turn one or three stock cards onto the waste. Refused on an empty stock:
/// recycling is its own move.
class Draw extends KlondikeMove {
  const Draw();

  @override
  Map<String, Object?> toJson() => const {'kind': 'draw'};

  @override
  bool operator ==(Object other) => other is Draw;

  @override
  int get hashCode => (Draw).hashCode;

  @override
  String toString() => 'Draw()';
}

/// Turn the waste back into the stock, face down, in its original order.
class Recycle extends KlondikeMove {
  const Recycle();

  @override
  Map<String, Object?> toJson() => const {'kind': 'recycle'};

  @override
  bool operator ==(Object other) => other is Recycle;

  @override
  int get hashCode => (Recycle).hashCode;

  @override
  String toString() => 'Recycle()';
}

/// Turn a face-down top card face up by hand. Legal in either game, only
/// while auto-flip is off.
class Flip extends Move {
  const Flip(this.column);

  final int column;

  @override
  Map<String, Object?> toJson() => {'kind': 'flip', 'column': column};

  @override
  bool operator ==(Object other) => other is Flip && other.column == column;

  @override
  int get hashCode => Object.hash(Flip, column);

  @override
  String toString() => 'Flip($column)';
}

const int klondikeColumns = 7;
const int klondikeCardCount = 52;

/// An immutable Klondike position with its options, score, clock and undo
/// history. Every operation returns a new game; the lists it exposes cannot
/// be changed.
class KlondikeGame extends Game {
  KlondikeGame._({
    required this.dealNumber,
    required this.options,
    required List<List<Card>> tableau,
    required List<Card> stock,
    required List<Card> waste,
    required List<List<Card>> foundations,
    required this.moveScore,
    required this.timeBonus,
    required this.moves,
    required this._elapsedMs,
    required this.lastDrawCount,
    required this.lastDelta,
    required this.winnable,
    required List<KlondikeMove>? solution,
    required this._previous,
    required this._lastUndone,
  }) : tableau = _fixedPiles(tableau),
       stock = _fixed(stock),
       waste = _fixed(waste),
       foundations = _fixedPiles(foundations),
       solution = solution == null ? null : _fixed(solution);

  /// Deals [dealNumber]: `standardDeck()` shuffled with `Rng(dealNumber)`,
  /// seven columns of 1..7 cards laid row by row from the end of the
  /// shuffled list with only each column's last card face up; the other 24
  /// are the stock, its top the list's end.
  factory KlondikeGame.deal(
    DealNumber dealNumber, [
    KlondikeOptions options = const KlondikeOptions(),
  ]) {
    final cards = shuffle(standardDeck(), Rng(dealNumber.value));
    final tableau = List.generate(klondikeColumns, (_) => <Card>[]);
    for (var row = 0; row < klondikeColumns; row++) {
      for (var column = row; column < klondikeColumns; column++) {
        final card = cards.removeLast();
        tableau[column].add(column == row ? card.up : card.down);
      }
    }
    return KlondikeGame._(
      dealNumber: dealNumber,
      options: options,
      tableau: tableau,
      stock: cards,
      waste: const [],
      foundations: List.generate(4, (_) => const <Card>[]),
      moveScore: KlondikeScoring.of(options.scoring)
          .delta(KlondikeScoreEvent.deal),
      timeBonus: 0,
      moves: 0,
      elapsedMs: 0,
      lastDrawCount: 0,
      lastDelta: 0,
      winnable: false,
      solution: null,
      previous: null,
      lastUndone: false,
    );
  }

  /// A position built by hand, for tests and the solver's replay. Checks
  /// that the piles hold each of the 52 cards exactly once. Piles are
  /// bottom-to-top; foundations are in `Suit` order.
  factory KlondikeGame.fromPiles({
    required List<List<Card>> tableau,
    List<Card> stock = const [],
    List<Card> waste = const [],
    List<List<Card>>? foundations,
    DealNumber? dealNumber,
    KlondikeOptions options = const KlondikeOptions(),
    int? moveScore,
    int moves = 0,
    Duration elapsed = Duration.zero,
  }) {
    foundations ??= List.generate(4, (_) => const <Card>[]);
    if (tableau.length != klondikeColumns) {
      throw ArgumentError('a Klondike tableau has $klondikeColumns columns');
    }
    if (foundations.length != 4) {
      throw ArgumentError('Klondike has four foundations');
    }
    final all = [
      for (final c in tableau) ...c,
      ...stock,
      ...waste,
      for (final f in foundations) ...f,
    ];
    final seen = <Card>{};
    for (final card in all) {
      if (!seen.add(card.down)) {
        throw ArgumentError('duplicate card ${card.down} in the piles');
      }
    }
    if (seen.length != klondikeCardCount) {
      throw ArgumentError(
        'the piles hold ${seen.length} distinct cards, not $klondikeCardCount',
      );
    }
    for (var i = 0; i < 4; i++) {
      final suit = Suit.values[i];
      for (var j = 0; j < foundations[i].length; j++) {
        final card = foundations[i][j];
        if (card.suit != suit || card.rank != j + 1) {
          throw ArgumentError('foundation $i is not ${suit.name} ace up');
        }
      }
    }
    if (stock.any((c) => c.faceUp)) {
      throw ArgumentError('the stock is face down');
    }
    return KlondikeGame._(
      dealNumber: dealNumber ?? DealNumber(1),
      options: options,
      tableau: tableau,
      stock: stock,
      waste: [for (final c in waste) c.up],
      foundations: [
        for (final f in foundations) [for (final c in f) c.up],
      ],
      moveScore:
          moveScore ??
          KlondikeScoring.of(options.scoring).delta(KlondikeScoreEvent.deal),
      timeBonus: 0,
      moves: moves,
      elapsedMs: elapsed.inMilliseconds,
      lastDrawCount: 0,
      lastDelta: 0,
      winnable: false,
      solution: null,
      previous: null,
      lastUndone: false,
    );
  }

  @override
  final DealNumber dealNumber;
  final KlondikeOptions options;

  /// Seven columns, bottom to top.
  final List<List<Card>> tableau;

  /// Face down; the top card is the last.
  final List<Card> stock;

  /// Face up; the top card is the last.
  final List<Card> waste;

  /// Four piles in `Suit` order: spades, hearts, diamonds, clubs.
  final List<List<Card>> foundations;

  /// The score from moves alone, before the time rules (#62).
  final int moveScore;

  @override
  final int timeBonus;

  @override
  final int moves;

  final int _elapsedMs;

  /// How many cards the last draw turned, so the board can fan the waste.
  final int lastDrawCount;

  @override
  final int lastDelta;

  /// True only for a game the winnable dealer proved (#68) or a saved game
  /// whose stored solution replayed (#69). `deal` never sets it.
  final bool winnable;

  /// The proven line from the deal, when [winnable].
  final List<KlondikeMove>? solution;

  @override
  final HistoryEntry? _previous;

  @override
  final bool _lastUndone;

  @override
  Duration get elapsed => Duration(milliseconds: _elapsedMs);

  KlondikeScoring get _table => KlondikeScoring.of(options.scoring);

  /// The move score after the time penalty and the floor, without the win
  /// bonus.
  int get _shownMoveScore {
    switch (options.scoring) {
      case ScoringMode.none:
        return 0;
      case ScoringMode.vegas:
        return moveScore;
      case ScoringMode.standard:
        final penalty = options.timed
            ? KlondikeScoring.timePenaltyPoints *
                  (_elapsedMs ~/
                      KlondikeScoring.timePenaltyPeriod.inMilliseconds)
            : 0;
        final shown = moveScore - penalty;
        return shown < 0 ? 0 : shown;
    }
  }

  @override
  int get score => _shownMoveScore + timeBonus;

  ScoringMode get scoring => options.scoring;

  int get foundationCount {
    var n = 0;
    for (final f in foundations) {
      n += f.length;
    }
    return n;
  }

  @override
  bool get isWon => foundationCount == klondikeCardCount;

  /// Every tableau card is face up.
  bool get allTableauFaceUp {
    for (final column in tableau) {
      for (final card in column) {
        if (!card.faceUp) return false;
      }
    }
    return true;
  }

  bool get lastUndone => _lastUndone;

  KlondikeGame _copy({
    List<List<Card>>? tableau,
    List<Card>? stock,
    List<Card>? waste,
    List<List<Card>>? foundations,
    int? moveScore,
    int? timeBonus,
    int? moves,
    int? elapsedMs,
    int? lastDrawCount,
    int? lastDelta,
    bool? winnable,
    List<KlondikeMove>? solution,
    bool clearSolution = false,
    HistoryEntry? previous,
    bool clearPrevious = false,
    bool? lastUndone,
  }) => KlondikeGame._(
    dealNumber: dealNumber,
    options: options,
    tableau: tableau ?? this.tableau,
    stock: stock ?? this.stock,
    waste: waste ?? this.waste,
    foundations: foundations ?? this.foundations,
    moveScore: moveScore ?? this.moveScore,
    timeBonus: timeBonus ?? this.timeBonus,
    moves: moves ?? this.moves,
    elapsedMs: elapsedMs ?? _elapsedMs,
    lastDrawCount: lastDrawCount ?? this.lastDrawCount,
    lastDelta: lastDelta ?? this.lastDelta,
    winnable: winnable ?? this.winnable,
    solution: clearSolution ? null : (solution ?? this.solution),
    previous: clearPrevious ? null : (previous ?? _previous),
    lastUndone: lastUndone ?? _lastUndone,
  );

  // ---------------------------------------------------------------- rules

  /// True when the cards of [column] from [start] up are all face up and
  /// each is one rank below and the opposite colour of the one beneath.
  static bool isAlternatingRun(List<Card> column, int start) {
    if (start < 0 || start >= column.length) return false;
    for (var i = start; i < column.length; i++) {
      final card = column[i];
      if (!card.faceUp) return false;
      if (i > start) {
        final below = column[i - 1];
        if (below.rank != card.rank + 1 || below.isRed == card.isRed) {
          return false;
        }
      }
    }
    return true;
  }

  /// The lowest index from which [column]'s top run is a valid run, or the
  /// column's length when it is empty.
  static int runBase(List<Card> column) {
    if (column.isEmpty) return 0;
    var base = column.length - 1;
    if (!column[base].faceUp) return column.length;
    while (base > 0) {
      final below = column[base - 1];
      final card = column[base];
      if (!below.faceUp ||
          below.rank != card.rank + 1 ||
          below.isRed == card.isRed) {
        break;
      }
      base--;
    }
    return base;
  }

  /// Why [card] cannot go on [column], or null when it can.
  static RefusalReason? tableauRefusal(List<Card> column, Card card) {
    if (column.isEmpty) {
      return card.isKing ? null : RefusalReason.emptyColumnNeedsKing;
    }
    final top = column.last;
    if (!top.faceUp) return RefusalReason.notFaceUp;
    if (top.isRed == card.isRed) return RefusalReason.colourMismatch;
    if (top.rank != card.rank + 1) return RefusalReason.rankMismatch;
    return null;
  }

  /// Why [card] cannot go on its foundation, or null when it can.
  RefusalReason? foundationRefusal(Card card) {
    final pile = foundations[card.suit.index];
    final next = pile.isEmpty ? aceRank : pile.last.rank + 1;
    return card.rank == next ? null : RefusalReason.foundationRankMismatch;
  }

  bool acceptsOnTableau(int column, Card card) =>
      tableauRefusal(tableau[column], card) == null;

  bool acceptsOnFoundation(Card card) => foundationRefusal(card) == null;

  // ---------------------------------------------------------------- apply

  @override
  ApplyResult<KlondikeGame> apply(Move move) {
    if (isWon) return const Refused(RefusalReason.gameOver);
    return switch (move) {
      MoveRun m => _moveRun(m),
      WasteToTableau m => _wasteToTableau(m),
      WasteToFoundation m => _wasteToFoundation(m),
      TableauToFoundation m => _tableauToFoundation(m),
      FoundationToTableau m => _foundationToTableau(m),
      Draw m => _draw(m),
      Recycle m => _recycle(m),
      Flip m => _flip(m),
      MoveCards() ||
      DealRow() ||
      MoveGroup() => const Refused(RefusalReason.invalidMove),
    };
  }

  bool _validColumn(int c) => c >= 0 && c < klondikeColumns;

  ApplyResult<KlondikeGame> _moveRun(MoveRun m) {
    if (!_validColumn(m.from) || !_validColumn(m.to) || m.from == m.to) {
      return const Refused(RefusalReason.invalidMove);
    }
    final source = tableau[m.from];
    if (m.start < 0 || m.start >= source.length) {
      return const Refused(RefusalReason.invalidMove);
    }
    if (!source[m.start].faceUp) return const Refused(RefusalReason.notFaceUp);
    if (!isAlternatingRun(source, m.start)) {
      return const Refused(RefusalReason.notAlternatingRun);
    }
    final refusal = tableauRefusal(tableau[m.to], source[m.start]);
    if (refusal != null) return Refused(refusal);

    final moving = source.sublist(m.start);
    final newTableau = List<List<Card>>.of(tableau);
    newTableau[m.to] = [...tableau[m.to], ...moving];
    final flipped = _takeFromColumn(newTableau, m.from, m.start);
    return _commit(
      move: m,
      tableau: newTableau,
      effects: Effects(
        from: PileKind.tableau,
        to: PileKind.tableau,
        cardsMoved: moving.length,
        cardsFlipped: flipped,
      ),
      events: [if (flipped > 0) KlondikeScoreEvent.flip],
    );
  }

  /// Removes the cards from [start] up in column [column] of [tableau] (a
  /// mutable copy), auto-flipping the newly exposed card when the option is
  /// on. Returns how many cards were flipped.
  int _takeFromColumn(List<List<Card>> tableau, int column, int start) {
    final remaining = tableau[column].sublist(0, start);
    var flipped = 0;
    if (remaining.isNotEmpty && !remaining.last.faceUp && options.autoFlip) {
      remaining[remaining.length - 1] = remaining.last.up;
      flipped = 1;
    }
    tableau[column] = remaining;
    return flipped;
  }

  ApplyResult<KlondikeGame> _wasteToTableau(WasteToTableau m) {
    if (!_validColumn(m.to)) return const Refused(RefusalReason.invalidMove);
    if (waste.isEmpty) return const Refused(RefusalReason.emptySource);
    final card = waste.last;
    final refusal = tableauRefusal(tableau[m.to], card);
    if (refusal != null) return Refused(refusal);
    final newTableau = List<List<Card>>.of(tableau);
    newTableau[m.to] = [...tableau[m.to], card];
    return _commit(
      move: m,
      tableau: newTableau,
      waste: waste.sublist(0, waste.length - 1),
      effects: const Effects(
        from: PileKind.waste,
        to: PileKind.tableau,
        cardsMoved: 1,
      ),
      events: const [KlondikeScoreEvent.wasteToTableau],
    );
  }

  ApplyResult<KlondikeGame> _wasteToFoundation(WasteToFoundation m) {
    if (waste.isEmpty) return const Refused(RefusalReason.emptySource);
    final card = waste.last;
    final refusal = foundationRefusal(card);
    if (refusal != null) return Refused(refusal);
    return _commit(
      move: m,
      waste: waste.sublist(0, waste.length - 1),
      foundations: _withOnFoundation(card),
      effects: const Effects(
        from: PileKind.waste,
        to: PileKind.foundation,
        cardsMoved: 1,
      ),
      events: const [KlondikeScoreEvent.toFoundation],
    );
  }

  ApplyResult<KlondikeGame> _tableauToFoundation(TableauToFoundation m) {
    if (!_validColumn(m.from)) return const Refused(RefusalReason.invalidMove);
    final source = tableau[m.from];
    if (source.isEmpty) return const Refused(RefusalReason.emptySource);
    final card = source.last;
    if (!card.faceUp) return const Refused(RefusalReason.notFaceUp);
    final refusal = foundationRefusal(card);
    if (refusal != null) return Refused(refusal);
    final newTableau = List<List<Card>>.of(tableau);
    final flipped = _takeFromColumn(newTableau, m.from, source.length - 1);
    return _commit(
      move: m,
      tableau: newTableau,
      foundations: _withOnFoundation(card),
      effects: Effects(
        from: PileKind.tableau,
        to: PileKind.foundation,
        cardsMoved: 1,
        cardsFlipped: flipped,
      ),
      events: [
        KlondikeScoreEvent.toFoundation,
        if (flipped > 0) KlondikeScoreEvent.flip,
      ],
    );
  }

  ApplyResult<KlondikeGame> _foundationToTableau(FoundationToTableau m) {
    if (m.foundation < 0 || m.foundation > 3 || !_validColumn(m.to)) {
      return const Refused(RefusalReason.invalidMove);
    }
    final pile = foundations[m.foundation];
    if (pile.isEmpty) return const Refused(RefusalReason.emptySource);
    final card = pile.last;
    final refusal = tableauRefusal(tableau[m.to], card);
    if (refusal != null) return Refused(refusal);
    final newTableau = List<List<Card>>.of(tableau);
    newTableau[m.to] = [...tableau[m.to], card];
    final newFoundations = List<List<Card>>.of(foundations);
    newFoundations[m.foundation] = pile.sublist(0, pile.length - 1);
    return _commit(
      move: m,
      tableau: newTableau,
      foundations: newFoundations,
      effects: const Effects(
        from: PileKind.foundation,
        to: PileKind.tableau,
        cardsMoved: 1,
      ),
      events: const [KlondikeScoreEvent.foundationToTableau],
    );
  }

  ApplyResult<KlondikeGame> _draw(Draw m) {
    if (stock.isEmpty) return const Refused(RefusalReason.stockEmpty);
    final n = stock.length < options.draw.count
        ? stock.length
        : options.draw.count;
    final turned = [
      for (var i = stock.length - 1; i >= stock.length - n; i--) stock[i].up,
    ];
    return _commit(
      move: m,
      stock: stock.sublist(0, stock.length - n),
      waste: [...waste, ...turned],
      lastDrawCount: n,
      effects: Effects(from: PileKind.stock, to: PileKind.waste, cardsDrawn: n),
      events: const [],
    );
  }

  ApplyResult<KlondikeGame> _recycle(Recycle m) {
    if (stock.isNotEmpty) return const Refused(RefusalReason.stockNotEmpty);
    if (waste.isEmpty) return const Refused(RefusalReason.wasteEmpty);
    return _commit(
      move: m,
      stock: [for (var i = waste.length - 1; i >= 0; i--) waste[i].down],
      waste: const [],
      lastDrawCount: 0,
      effects: const Effects(
        from: PileKind.waste,
        to: PileKind.stock,
        recycled: true,
      ),
      events: const [KlondikeScoreEvent.recycle],
    );
  }

  ApplyResult<KlondikeGame> _flip(Flip m) {
    if (!_validColumn(m.column)) {
      return const Refused(RefusalReason.invalidMove);
    }
    final column = tableau[m.column];
    if (options.autoFlip || column.isEmpty || column.last.faceUp) {
      return const Refused(RefusalReason.flipNotAllowed);
    }
    final newTableau = List<List<Card>>.of(tableau);
    newTableau[m.column] = [
      ...column.sublist(0, column.length - 1),
      column.last.up,
    ];
    return _commit(
      move: m,
      tableau: newTableau,
      effects: const Effects(cardsFlipped: 1),
      events: const [KlondikeScoreEvent.flip],
    );
  }

  List<List<Card>> _withOnFoundation(Card card) {
    final out = List<List<Card>>.of(foundations);
    out[card.suit.index] = [...foundations[card.suit.index], card.up];
    return out;
  }

  /// Builds the next game: new piles, the score delta from [events] with
  /// the mode's floor applied to the sum, the move counted, the history
  /// entry recorded, and the win bonus added when this move wins a timed
  /// standard game.
  Applied<KlondikeGame> _commit({
    required Move move,
    List<List<Card>>? tableau,
    List<Card>? stock,
    List<Card>? waste,
    List<List<Card>>? foundations,
    int? lastDrawCount,
    required Effects effects,
    required List<KlondikeScoreEvent> events,
  }) {
    var delta = 0;
    for (final event in events) {
      delta += _table.delta(event);
    }
    var newMoveScore = moveScore + delta;
    final floor = _table.floor;
    if (floor != null && newMoveScore < floor) newMoveScore = floor;

    var next = _copy(
      tableau: tableau,
      stock: stock,
      waste: waste,
      foundations: foundations,
      moveScore: newMoveScore,
      moves: moves + 1,
      lastDrawCount: lastDrawCount,
      previous: HistoryEntry(this, move, effects),
      lastUndone: false,
    );
    var bonus = 0;
    if (next.isWon &&
        options.timed &&
        options.scoring == ScoringMode.standard) {
      bonus = winTimeBonus(elapsed);
    }
    next = next._copy(
      timeBonus: timeBonus + bonus,
      lastDelta: next._shownMoveScore - _shownMoveScore,
    );
    return Applied(next, effects);
  }

  // ---------------------------------------------------------- enumeration

  /// Every legal move, pointless ones included, in a fixed order: sources
  /// waste, columns 0–6 (bottom-most run start first), foundations;
  /// destinations foundation then columns 0–6; then draw, recycle, flips.
  @override
  List<Move> legalMoves() {
    if (isWon) return const [];
    final out = <Move>[];
    if (waste.isNotEmpty) {
      final card = waste.last;
      if (acceptsOnFoundation(card)) out.add(const WasteToFoundation());
      for (var d = 0; d < klondikeColumns; d++) {
        if (acceptsOnTableau(d, card)) out.add(WasteToTableau(d));
      }
    }
    for (var c = 0; c < klondikeColumns; c++) {
      final column = tableau[c];
      if (column.isEmpty) continue;
      final top = column.length - 1;
      for (var start = runBase(column); start <= top; start++) {
        final card = column[start];
        if (start == top && acceptsOnFoundation(card)) {
          out.add(TableauToFoundation(c));
        }
        for (var d = 0; d < klondikeColumns; d++) {
          if (d != c && acceptsOnTableau(d, card)) {
            out.add(MoveRun(c, start, d));
          }
        }
      }
    }
    for (var f = 0; f < 4; f++) {
      if (foundations[f].isEmpty) continue;
      final card = foundations[f].last;
      for (var d = 0; d < klondikeColumns; d++) {
        if (acceptsOnTableau(d, card)) out.add(FoundationToTableau(f, d));
      }
    }
    if (stock.isNotEmpty) {
      out.add(const Draw());
    } else if (waste.isNotEmpty) {
      out.add(const Recycle());
    }
    if (!options.autoFlip) {
      for (var c = 0; c < klondikeColumns; c++) {
        final column = tableau[c];
        if (column.isNotEmpty && !column.last.faceUp) out.add(Flip(c));
      }
    }
    return out;
  }

  // ------------------------------------------------- clock, undo, restart

  @override
  KlondikeGame tick(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    if (isWon) return this;
    return _copy(elapsedMs: _elapsedMs + duration.inMilliseconds, lastDelta: 0);
  }

  @override
  bool canUndo({required bool unlimited}) =>
      _canUndo(this, unlimited: unlimited);

  /// The previous state exactly — cards, score, moves — with the current
  /// clock kept. Never counts as a move. Returns `Refused(cannotUndo)` when
  /// the history or the setting forbids it.
  @override
  ApplyResult<KlondikeGame> undo({required bool unlimited}) {
    if (!canUndo(unlimited: unlimited)) {
      return const Refused(RefusalReason.cannotUndo);
    }
    final entry = _previous!;
    final before = entry.before as KlondikeGame;
    return Applied(
      before._copy(
        elapsedMs: _elapsedMs,
        lastDelta: 0,
        lastUndone: true,
        winnable: winnable,
        solution: solution,
      ),
      Effects(steps: [entry.effects]),
    );
  }

  /// A fresh deal of the same number and options: clock at zero, history
  /// empty, Vegas score back to −52. A proven winnable game keeps its
  /// solution.
  @override
  KlondikeGame restart() => KlondikeGame.deal(
    dealNumber,
    options,
  )._copy(winnable: winnable, solution: solution);

  @override
  Map<String, Object?> toJson() => _klondikeToJson(this);

  static KlondikeGame fromJson(Map<String, Object?> json) =>
      _klondikeFromJson(json);

  // ----------------------------------------------------------------- value

  @override
  bool operator ==(Object other) =>
      other is KlondikeGame &&
      other.dealNumber == dealNumber &&
      other.options == options &&
      other.moveScore == moveScore &&
      other.timeBonus == timeBonus &&
      other.moves == moves &&
      _sameCards(other.stock, stock) &&
      _sameCards(other.waste, waste) &&
      _samePiles(other.foundations, foundations) &&
      _samePiles(other.tableau, tableau);

  @override
  int get hashCode => Object.hash(
    dealNumber,
    options,
    moveScore,
    timeBonus,
    moves,
    _hashCards(stock),
    _hashCards(waste),
    _hashPiles(foundations),
    _hashPiles(tableau),
  );

  @override
  String toString() {
    final b = StringBuffer('KlondikeGame #${dealNumber.value} $options\n');
    for (var c = 0; c < klondikeColumns; c++) {
      b.writeln('  t$c: ${tableau[c].join(' ')}');
    }
    b.writeln('  stock: ${stock.join(' ')}');
    b.writeln('  waste: ${waste.join(' ')}');
    for (var f = 0; f < 4; f++) {
      b.writeln('  f${Suit.values[f].letter}: ${foundations[f].join(' ')}');
    }
    b.write('  score $score moves $moves elapsed ${elapsed.inSeconds}s');
    return b.toString();
  }
}
