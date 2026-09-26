part of 'game.dart';

/// A Spider game's options, fixed at the deal (#61, #63).
class SpiderOptions {
  const SpiderOptions({
    this.suits = SpiderSuits.one,
    this.relaxed = false,
    this.autoFlip = true,
    this.timed = true,
  });

  final SpiderSuits suits;

  /// Relaxed lets a row be dealt onto an empty column; strict (the default)
  /// refuses.
  final bool relaxed;

  /// Turn an uncovered card face up at once. Off, `Flip` is a move.
  final bool autoFlip;

  /// Whether a fast win earns the time bonus. The clock runs either way.
  final bool timed;

  SpiderOptions copyWith({
    SpiderSuits? suits,
    bool? relaxed,
    bool? autoFlip,
    bool? timed,
  }) => SpiderOptions(
    suits: suits ?? this.suits,
    relaxed: relaxed ?? this.relaxed,
    autoFlip: autoFlip ?? this.autoFlip,
    timed: timed ?? this.timed,
  );

  Map<String, Object?> toJson() => {
    'suits': suits.count,
    'relaxed': relaxed,
    'autoFlip': autoFlip,
    'timed': timed,
  };

  @override
  bool operator ==(Object other) =>
      other is SpiderOptions &&
      other.suits == suits &&
      other.relaxed == relaxed &&
      other.autoFlip == autoFlip &&
      other.timed == timed;

  @override
  int get hashCode => Object.hash(suits, relaxed, autoFlip, timed);

  @override
  String toString() =>
      'SpiderOptions(${suits.count} suit(s), relaxed $relaxed, '
      'autoFlip $autoFlip, timed $timed)';
}

/// A Spider move.
sealed class SpiderMove extends Move {
  const SpiderMove();
}

/// The cards from [start] in column [from] onto column [to].
class MoveCards extends SpiderMove {
  const MoveCards(this.from, this.start, this.to);

  final int from;
  final int start;
  final int to;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'move',
    'from': from,
    'start': start,
    'to': to,
  };

  @override
  bool operator ==(Object other) =>
      other is MoveCards &&
      other.from == from &&
      other.start == start &&
      other.to == to;

  @override
  int get hashCode => Object.hash(MoveCards, from, start, to);

  @override
  String toString() => 'MoveCards($from[$start] → $to)';
}

/// Deal the next stock row: one face-up card on every column.
class DealRow extends SpiderMove {
  const DealRow();

  @override
  Map<String, Object?> toJson() => const {'kind': 'dealRow'};

  @override
  bool operator ==(Object other) => other is DealRow;

  @override
  int get hashCode => (DealRow).hashCode;

  @override
  String toString() => 'DealRow()';
}

const int spiderColumns = 10;
const int spiderCardCount = 104;
const int spiderStockRows = 5;
const int spiderRunLength = 13;
const int spiderRunsToWin = 8;

/// An immutable Spider position with its options, score, clock and undo
/// history.
class SpiderGame extends Game {
  SpiderGame._({
    required this.dealNumber,
    required this.options,
    required List<List<Card>> tableau,
    required List<List<Card>> stock,
    required List<Suit> completed,
    required this.moveScore,
    required this.timeBonus,
    required this.moves,
    required this._elapsedMs,
    required this.lastDelta,
    required this._previous,
    required this._lastUndone,
  }) : tableau = _fixedPiles(tableau),
       stock = _fixedPiles(stock),
       completed = _fixed(completed);

  /// Deals [dealNumber]: `spiderDeck(suits)` shuffled with `Rng(dealNumber)`,
  /// dealt round-robin from the end of the shuffled list into ten columns of
  /// 6,6,6,6,5,5,5,5,5,5 with only each last card face up; the other 50 form
  /// five stock rows of ten, the first row dealt first, card i to column i.
  factory SpiderGame.deal(
    DealNumber dealNumber, [
    SpiderOptions options = const SpiderOptions(),
  ]) {
    final cards = shuffle(spiderDeck(options.suits), Rng(dealNumber.value));
    final tableau = List.generate(spiderColumns, (_) => <Card>[]);
    for (var row = 0; row < 6; row++) {
      for (var column = 0; column < spiderColumns; column++) {
        final height = column < 4 ? 6 : 5;
        if (row >= height) continue;
        final card = cards.removeLast();
        tableau[column].add(row == height - 1 ? card.up : card.down);
      }
    }
    final stock = <List<Card>>[];
    for (var row = 0; row < spiderStockRows; row++) {
      stock.add([
        for (var i = 0; i < spiderColumns; i++) cards.removeLast().down,
      ]);
    }
    assert(cards.isEmpty);
    return SpiderGame._(
      dealNumber: dealNumber,
      options: options,
      tableau: tableau,
      stock: stock,
      completed: const [],
      moveScore: SpiderScoring.atDeal,
      timeBonus: 0,
      moves: 0,
      elapsedMs: 0,
      lastDelta: 0,
      previous: null,
      lastUndone: false,
    );
  }

  /// A position built by hand. Checks the deck multiset (each completed run
  /// counts as its 13 cards), that face-down cards lie only beneath face-up
  /// ones, and that stock rows hold ten cards.
  factory SpiderGame.fromPiles({
    required List<List<Card>> tableau,
    List<List<Card>> stock = const [],
    List<Suit> completed = const [],
    DealNumber? dealNumber,
    SpiderOptions options = const SpiderOptions(),
    int moveScore = SpiderScoring.atDeal,
    int moves = 0,
    Duration elapsed = Duration.zero,
  }) {
    if (tableau.length != spiderColumns) {
      throw ArgumentError('a Spider tableau has $spiderColumns columns');
    }
    for (final row in stock) {
      if (row.length != spiderColumns) {
        throw ArgumentError('a Spider stock row holds $spiderColumns cards');
      }
    }
    if (stock.length > spiderStockRows) {
      throw ArgumentError('Spider has at most $spiderStockRows stock rows');
    }
    for (final column in tableau) {
      var seenUp = false;
      for (final card in column) {
        if (card.faceUp) {
          seenUp = true;
        } else if (seenUp) {
          throw ArgumentError('a face-down card lies on a face-up one');
        }
      }
    }
    final expected = [for (final c in spiderDeck(options.suits)) c.toJson()]
      ..sort();
    final actual = [
      for (final c in tableau)
        for (final card in c) card.down.toJson(),
      for (final r in stock)
        for (final card in r) card.down.toJson(),
      for (final suit in completed)
        for (var rank = aceRank; rank <= kingRank; rank++)
          Card(rank, suit).toJson(),
    ]..sort();
    if (expected.length != actual.length) {
      throw ArgumentError(
        'the piles hold ${actual.length} cards, not ${expected.length}',
      );
    }
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) {
        throw ArgumentError(
          'the piles are not the ${options.suits.name}-suit deck',
        );
      }
    }
    return SpiderGame._(
      dealNumber: dealNumber ?? DealNumber(1),
      options: options,
      tableau: tableau,
      stock: [
        for (final r in stock) [for (final c in r) c.down],
      ],
      completed: completed,
      moveScore: moveScore,
      timeBonus: 0,
      moves: moves,
      elapsedMs: elapsed.inMilliseconds,
      lastDelta: 0,
      previous: null,
      lastUndone: false,
    );
  }

  @override
  final DealNumber dealNumber;
  final SpiderOptions options;

  /// Ten columns, bottom to top.
  final List<List<Card>> tableau;

  /// The rows still to deal; the first is dealt next, card i to column i.
  final List<List<Card>> stock;

  /// The suit of each completed run, in completion order.
  final List<Suit> completed;

  /// The score from moves and runs alone, before the win bonus (#63).
  final int moveScore;

  @override
  final int timeBonus;

  @override
  final int moves;

  final int _elapsedMs;

  @override
  final int lastDelta;

  @override
  final HistoryEntry? _previous;

  @override
  final bool _lastUndone;

  @override
  Duration get elapsed => Duration(milliseconds: _elapsedMs);

  @override
  int get score => moveScore + timeBonus;

  int get rowsLeft => stock.length;

  int get runsCompleted => completed.length;

  @override
  bool get isWon => completed.length == spiderRunsToWin;

  bool get lastUndone => _lastUndone;

  bool get hasEmptyColumn => tableau.any((c) => c.isEmpty);

  SpiderGame _copy({
    List<List<Card>>? tableau,
    List<List<Card>>? stock,
    List<Suit>? completed,
    int? moveScore,
    int? timeBonus,
    int? moves,
    int? elapsedMs,
    int? lastDelta,
    HistoryEntry? previous,
    bool? lastUndone,
  }) => SpiderGame._(
    dealNumber: dealNumber,
    options: options,
    tableau: tableau ?? this.tableau,
    stock: stock ?? this.stock,
    completed: completed ?? this.completed,
    moveScore: moveScore ?? this.moveScore,
    timeBonus: timeBonus ?? this.timeBonus,
    moves: moves ?? this.moves,
    elapsedMs: elapsedMs ?? _elapsedMs,
    lastDelta: lastDelta ?? this.lastDelta,
    previous: previous ?? _previous,
    lastUndone: lastUndone ?? _lastUndone,
  );

  // ---------------------------------------------------------------- rules

  /// True when the cards of [column] from [start] up are all face up, the
  /// same suit, and each one rank below the one beneath.
  static bool isSameSuitRun(List<Card> column, int start) {
    if (start < 0 || start >= column.length) return false;
    for (var i = start; i < column.length; i++) {
      final card = column[i];
      if (!card.faceUp) return false;
      if (i > start) {
        final below = column[i - 1];
        if (below.rank != card.rank + 1 || below.suit != card.suit) {
          return false;
        }
      }
    }
    return true;
  }

  /// The lowest index from which [column]'s top run is a same-suit run, or
  /// the column's length when the top card is face down or the column empty.
  static int runBase(List<Card> column) {
    if (column.isEmpty) return 0;
    var base = column.length - 1;
    if (!column[base].faceUp) return column.length;
    while (base > 0) {
      final below = column[base - 1];
      final card = column[base];
      if (!below.faceUp ||
          below.rank != card.rank + 1 ||
          below.suit != card.suit) {
        break;
      }
      base--;
    }
    return base;
  }

  /// Why [card] cannot go on [column], or null when it can: an empty column
  /// takes anything; otherwise the top must be face up and one rank higher.
  static RefusalReason? tableauRefusal(List<Card> column, Card card) {
    if (column.isEmpty) return null;
    final top = column.last;
    if (!top.faceUp) return RefusalReason.notFaceUp;
    if (top.rank != card.rank + 1) return RefusalReason.rankMismatch;
    return null;
  }

  bool acceptsOnTableau(int column, Card card) =>
      tableauRefusal(tableau[column], card) == null;

  /// Whether the next row may be dealt: stock left, and no empty column
  /// unless the relaxed rule is on.
  bool get canDealRow =>
      stock.isNotEmpty && (options.relaxed || !hasEmptyColumn);

  // ---------------------------------------------------------------- apply

  @override
  ApplyResult<SpiderGame> apply(Move move) {
    if (isWon) return const Refused(RefusalReason.gameOver);
    return switch (move) {
      MoveCards m => _moveCards(m),
      DealRow m => _dealRow(m),
      Flip m => _flip(m),
      KlondikeMove() || MoveGroup() => const Refused(RefusalReason.invalidMove),
    };
  }

  bool _validColumn(int c) => c >= 0 && c < spiderColumns;

  ApplyResult<SpiderGame> _moveCards(MoveCards m) {
    if (!_validColumn(m.from) || !_validColumn(m.to) || m.from == m.to) {
      return const Refused(RefusalReason.invalidMove);
    }
    final source = tableau[m.from];
    if (m.start < 0 || m.start >= source.length) {
      return const Refused(RefusalReason.invalidMove);
    }
    if (!source[m.start].faceUp) return const Refused(RefusalReason.notFaceUp);
    if (!isSameSuitRun(source, m.start)) {
      return const Refused(RefusalReason.notSameSuitRun);
    }
    final refusal = tableauRefusal(tableau[m.to], source[m.start]);
    if (refusal != null) return Refused(refusal);

    final moving = source.sublist(m.start);
    final newTableau = List<List<Card>>.of(tableau);
    newTableau[m.to] = [...tableau[m.to], ...moving];
    final remaining = source.sublist(0, m.start);
    var flipped = 0;
    if (remaining.isNotEmpty && !remaining.last.faceUp && options.autoFlip) {
      remaining[remaining.length - 1] = remaining.last.up;
      flipped = 1;
    }
    newTableau[m.from] = remaining;
    return _commit(
      move: m,
      tableau: newTableau,
      effects: Effects(
        from: PileKind.tableau,
        to: PileKind.tableau,
        cardsMoved: moving.length,
        cardsFlipped: flipped,
      ),
    );
  }

  ApplyResult<SpiderGame> _dealRow(DealRow m) {
    if (stock.isEmpty) return const Refused(RefusalReason.stockEmpty);
    if (!options.relaxed && hasEmptyColumn) {
      return const Refused(RefusalReason.emptyColumnStrict);
    }
    final row = stock.first;
    final newTableau = [
      for (var c = 0; c < spiderColumns; c++) [...tableau[c], row[c].up],
    ];
    return _commit(
      move: m,
      tableau: newTableau,
      stock: stock.sublist(1),
      effects: const Effects(
        from: PileKind.stock,
        to: PileKind.tableau,
        cardsDrawn: spiderColumns,
        rowDealt: true,
      ),
    );
  }

  ApplyResult<SpiderGame> _flip(Flip m) {
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
    );
  }

  /// Removes every complete K→A same-suit run, left to right, flipping the
  /// exposed card when auto-flip is on, and repeats until none is left.
  /// Returns the suits removed, in order, and how many cards were flipped;
  /// [tableau] is updated in place.
  (List<Suit>, int) _removeCompletedRuns(List<List<Card>> tableau) {
    final removed = <Suit>[];
    var flips = 0;
    var again = true;
    while (again) {
      again = false;
      for (var c = 0; c < spiderColumns; c++) {
        final column = tableau[c];
        if (column.length < spiderRunLength) continue;
        final start = column.length - spiderRunLength;
        if (column[start].rank != kingRank || !isSameSuitRun(column, start)) {
          continue;
        }
        removed.add(column[start].suit);
        final remaining = column.sublist(0, start);
        if (remaining.isNotEmpty &&
            !remaining.last.faceUp &&
            options.autoFlip) {
          remaining[remaining.length - 1] = remaining.last.up;
          flips++;
        }
        tableau[c] = remaining;
        again = true;
      }
    }
    return (removed, flips);
  }

  /// Builds the next game: the move costs one point, floored at 0, then each
  /// completed run adds its bonus; the move is counted, the history entry
  /// recorded, and the win bonus added when a timed game is won.
  Applied<SpiderGame> _commit({
    required Move move,
    required List<List<Card>> tableau,
    List<List<Card>>? stock,
    required Effects effects,
  }) {
    final (removed, extraFlips) = _removeCompletedRuns(tableau);
    final fullEffects = Effects(
      from: effects.from,
      to: effects.to,
      cardsMoved: effects.cardsMoved,
      cardsFlipped: effects.cardsFlipped + extraFlips,
      cardsDrawn: effects.cardsDrawn,
      rowDealt: effects.rowDealt,
      runsCompleted: removed,
    );

    var newMoveScore = moveScore + SpiderScoring.perMove;
    if (newMoveScore < SpiderScoring.floor) newMoveScore = SpiderScoring.floor;
    newMoveScore += SpiderScoring.perRun * removed.length;

    final newCompleted = [...completed, ...removed];
    var next = _copy(
      tableau: tableau,
      stock: stock,
      completed: newCompleted,
      moveScore: newMoveScore,
      moves: moves + 1,
      lastDelta: newMoveScore - moveScore,
      previous: HistoryEntry(this, move, fullEffects),
      lastUndone: false,
    );
    if (next.isWon && options.timed) {
      next = next._copy(timeBonus: timeBonus + winTimeBonus(elapsed));
    }
    return Applied(next, fullEffects);
  }

  // ---------------------------------------------------------- enumeration

  /// Every legal move: flips first (auto-flip off), then every valid run
  /// start onto every column that accepts it (columns 0–9 in order), then
  /// `DealRow` when it is legal.
  @override
  List<Move> legalMoves() {
    if (isWon) return const [];
    final out = <Move>[];
    if (!options.autoFlip) {
      for (var c = 0; c < spiderColumns; c++) {
        final column = tableau[c];
        if (column.isNotEmpty && !column.last.faceUp) out.add(Flip(c));
      }
    }
    for (var c = 0; c < spiderColumns; c++) {
      final column = tableau[c];
      if (column.isEmpty) continue;
      final top = column.length - 1;
      for (var start = runBase(column); start <= top; start++) {
        final card = column[start];
        for (var d = 0; d < spiderColumns; d++) {
          if (d != c && acceptsOnTableau(d, card)) {
            out.add(MoveCards(c, start, d));
          }
        }
      }
    }
    if (canDealRow) out.add(const DealRow());
    return out;
  }

  // ------------------------------------------------- clock, undo, restart

  @override
  SpiderGame tick(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    if (isWon) return this;
    return _copy(elapsedMs: _elapsedMs + duration.inMilliseconds, lastDelta: 0);
  }

  @override
  bool canUndo({required bool unlimited}) =>
      _canUndo(this, unlimited: unlimited);

  @override
  ApplyResult<SpiderGame> undo({required bool unlimited}) {
    if (!canUndo(unlimited: unlimited)) {
      return const Refused(RefusalReason.cannotUndo);
    }
    final entry = _previous!;
    final before = entry.before as SpiderGame;
    return Applied(
      before._copy(elapsedMs: _elapsedMs, lastDelta: 0, lastUndone: true),
      Effects(steps: [entry.effects]),
    );
  }

  @override
  SpiderGame restart() => SpiderGame.deal(dealNumber, options);

  @override
  Map<String, Object?> toJson() => _spiderToJson(this);

  static SpiderGame fromJson(Map<String, Object?> json) =>
      _spiderFromJson(json);

  // ----------------------------------------------------------------- value

  @override
  bool operator ==(Object other) =>
      other is SpiderGame &&
      other.dealNumber == dealNumber &&
      other.options == options &&
      other.moveScore == moveScore &&
      other.timeBonus == timeBonus &&
      other.moves == moves &&
      _sameSuits(other.completed, completed) &&
      _samePiles(other.stock, stock) &&
      _samePiles(other.tableau, tableau);

  @override
  int get hashCode => Object.hash(
    dealNumber,
    options,
    moveScore,
    timeBonus,
    moves,
    Object.hashAll(completed),
    _hashPiles(stock),
    _hashPiles(tableau),
  );

  @override
  String toString() {
    final b = StringBuffer('SpiderGame #${dealNumber.value} $options\n');
    for (var c = 0; c < spiderColumns; c++) {
      b.writeln('  t$c: ${tableau[c].join(' ')}');
    }
    b.writeln('  stock rows: ${stock.length}');
    b.writeln('  completed: ${completed.map((s) => s.letter).join(' ')}');
    b.write('  score $score moves $moves elapsed ${elapsed.inSeconds}s');
    return b.toString();
  }
}

bool _sameSuits(List<Suit> a, List<Suit> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
