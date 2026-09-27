part of 'game.dart';

// Versioned JSON for both games (#69).
//
// A saved game is its deal number, options, piles, counters and the list of
// moves applied since the deal. Loading re-deals from the number and options
// and replays the moves — which proves the history chains — then refuses
// unless the result matches the saved piles exactly. Only format 1 exists.

/// The current save format. Bump it when a saved game would no longer load
/// the same way, and keep `test/fixtures/save_v1.json` loading.
const int saveFormat = 1;

/// A generous ceiling on a single game's elapsed time (365 days), well
/// short of where `Duration(milliseconds: elapsedMs)` could overflow its
/// internal microseconds — a corrupted or hand-edited `elapsedMs` is
/// refused here rather than crashing the load.
const int _maxElapsedMs = 365 * 24 * 3600 * 1000;

/// Why a saved game could not be loaded. Thrown, never a crash.
sealed class SaveFormatError implements Exception {
  const SaveFormatError(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The `format` field is not one this build reads.
class UnsupportedFormatError extends SaveFormatError {
  const UnsupportedFormatError(this.format)
    : super('unsupported save format $format');

  final Object? format;
}

/// A required field is absent.
class MissingFieldError extends SaveFormatError {
  const MissingFieldError(this.field) : super('missing field "$field"');

  final String field;
}

/// A field is present but not of the shape or range it must have.
class InvalidValueError extends SaveFormatError {
  const InvalidValueError(this.field, String detail)
    : super('"$field": $detail');

  final String field;
}

/// The cards do not form a valid deck, or the replayed history does not
/// reach the saved piles.
class InvalidDeckError extends SaveFormatError {
  const InvalidDeckError(super.message);
}

// ------------------------------------------------------------------ writing

List<String> _pileJson(List<Card> pile) => [for (final c in pile) c.toJson()];

Map<String, Object?> _klondikeToJson(KlondikeGame g) => {
  'format': saveFormat,
  'game': 'klondike',
  'deal': g.dealNumber.value,
  'options': g.options.toJson(),
  'tableau': [for (final column in g.tableau) _pileJson(column)],
  'stock': _pileJson(g.stock),
  'waste': _pileJson(g.waste),
  'foundations': [for (final f in g.foundations) _pileJson(f)],
  'moveScore': g.moveScore,
  'timeBonus': g.timeBonus,
  'moves': g.moves,
  'elapsedMs': g._elapsedMs,
  'lastDrawCount': g.lastDrawCount,
  'lastUndone': g._lastUndone,
  'history': [for (final m in g.historyMoves) m.toJson()],
  'winnable': g.winnable,
  if (g.solution != null) 'solution': [for (final m in g.solution!) m.toJson()],
};

Map<String, Object?> _spiderToJson(SpiderGame g) => {
  'format': saveFormat,
  'game': 'spider',
  'deal': g.dealNumber.value,
  'options': g.options.toJson(),
  'tableau': [for (final column in g.tableau) _pileJson(column)],
  'stock': [for (final row in g.stock) _pileJson(row)],
  'completed': [for (final s in g.completed) s.letter],
  'moveScore': g.moveScore,
  'timeBonus': g.timeBonus,
  'moves': g.moves,
  'elapsedMs': g._elapsedMs,
  'lastUndone': g._lastUndone,
  'history': [for (final m in g.historyMoves) m.toJson()],
};

// ------------------------------------------------------------------ reading

Object? _require(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) throw MissingFieldError(field);
  return json[field];
}

/// [fallback] when [field] is absent, so an older save missing a field
/// added later still loads (#135) — present but malformed still throws.
bool _boolOr(Map<String, Object?> json, String field, bool fallback) {
  if (!json.containsKey(field)) return fallback;
  final value = json[field];
  if (value is! bool) {
    throw InvalidValueError(field, 'must be a bool, not $value');
  }
  return value;
}

int _int(Map<String, Object?> json, String field, {int min = 0, int? max}) {
  final value = _require(json, field);
  if (value is! int) {
    throw InvalidValueError(field, 'must be an int, not $value');
  }
  if (value < min || (max != null && value > max)) {
    throw InvalidValueError(field, '$value is outside $min..${max ?? '∞'}');
  }
  return value;
}

Map<String, Object?> _map(Map<String, Object?> json, String field) {
  final value = _require(json, field);
  if (value is! Map) throw InvalidValueError(field, 'must be an object');
  return value.cast<String, Object?>();
}

List<Object?> _list(Map<String, Object?> json, String field, {int? length}) {
  final value = _require(json, field);
  if (value is! List) throw InvalidValueError(field, 'must be a list');
  if (length != null && value.length != length) {
    throw InvalidValueError(
      field,
      'must hold $length entries, not ${value.length}',
    );
  }
  return value;
}

List<Card> _pile(Object? value, String field) {
  if (value is! List) throw InvalidValueError(field, 'a pile must be a list');
  try {
    return [for (final c in value) Card.fromJson(c)];
  } on FormatException catch (e) {
    throw InvalidValueError(field, e.message);
  }
}

List<List<Card>> _piles(Map<String, Object?> json, String field, int count) {
  final raw = _list(json, field, length: count);
  return [for (var i = 0; i < raw.length; i++) _pile(raw[i], '$field[$i]')];
}

List<Move> _moves(Map<String, Object?> json, String field) {
  final raw = _list(json, field);
  final out = <Move>[];
  for (var i = 0; i < raw.length; i++) {
    final m = raw[i];
    if (m is! Map) {
      throw InvalidValueError('$field[$i]', 'a move must be an object');
    }
    try {
      out.add(_moveFromJson(m.cast<String, Object?>()));
    } on FormatException catch (e) {
      throw InvalidValueError('$field[$i]', e.message);
    }
  }
  return out;
}

void _checkFormat(Map<String, Object?> json) {
  final format = _require(json, 'format');
  if (format != saveFormat) throw UnsupportedFormatError(format);
}

/// Every card exactly once against [expected] (a multiset), else
/// [InvalidDeckError].
void _checkDeck(Iterable<Card> cards, List<Card> expected, String what) {
  final have = [for (final c in cards) c.down.toJson()]..sort();
  final want = [for (final c in expected) c.toJson()]..sort();
  if (have.length != want.length) {
    throw InvalidDeckError(
      '$what holds ${have.length} cards, not ${want.length}',
    );
  }
  for (var i = 0; i < have.length; i++) {
    if (have[i] != want[i]) {
      throw InvalidDeckError('$what is not a complete deck (near ${have[i]})');
    }
  }
}

/// Replays [moves] from [deal]; a refusal is an [InvalidDeckError].
G _replay<G extends Game>(G deal, List<Move> moves) {
  Game g = deal;
  for (var i = 0; i < moves.length; i++) {
    final move = moves[i];
    final result = move is MoveGroup ? g.applyAll(move.moves) : g.apply(move);
    switch (result) {
      case Applied(:final game):
        g = game;
      case Refused(:final reason):
        throw InvalidDeckError('history move $i ($move) was refused: $reason');
    }
  }
  return g as G;
}

Game _gameFromJson(Map<String, Object?> json) {
  _checkFormat(json);
  final game = _require(json, 'game');
  return switch (game) {
    'klondike' => _klondikeFromJson(json),
    'spider' => _spiderFromJson(json),
    _ => throw InvalidValueError('game', 'unknown game $game'),
  };
}

KlondikeGame _klondikeFromJson(Map<String, Object?> json) {
  _checkFormat(json);
  if (_require(json, 'game') != 'klondike') {
    throw InvalidValueError('game', 'not a Klondike save');
  }
  final deal = DealNumber(
    _int(json, 'deal', min: DealNumber.min, max: DealNumber.max),
  );
  final KlondikeOptions options;
  try {
    options = KlondikeOptions.fromJson(_map(json, 'options'));
  } on FormatException catch (e) {
    throw InvalidValueError('options', e.message);
  }
  final tableau = _piles(json, 'tableau', klondikeColumns);
  final stock = _pile(_require(json, 'stock'), 'stock');
  final waste = _pile(_require(json, 'waste'), 'waste');
  final foundations = _piles(json, 'foundations', 4);
  _checkDeck(
    [
      for (final c in tableau) ...c,
      ...stock,
      ...waste,
      for (final f in foundations) ...f,
    ],
    standardDeck(),
    'the saved position',
  );
  for (final card in stock) {
    if (card.faceUp) throw InvalidDeckError('the stock holds a face-up card');
  }
  for (final card in waste) {
    if (!card.faceUp) {
      throw InvalidDeckError('the waste holds a face-down card');
    }
  }
  for (final column in tableau) {
    var seenUp = false;
    for (final card in column) {
      if (card.faceUp) {
        seenUp = true;
      } else if (seenUp) {
        throw InvalidDeckError('a face-down card lies on a face-up one');
      }
    }
  }
  final moveScore = _int(json, 'moveScore', min: -1000000, max: 1000000);
  final timeBonus = _int(json, 'timeBonus', max: timeBonusNumerator);
  final moves = _int(json, 'moves');
  final elapsedMs = _int(json, 'elapsedMs', max: _maxElapsedMs);
  final lastDrawCount = _int(json, 'lastDrawCount', max: 3);
  final lastUndone = _boolOr(json, 'lastUndone', false);
  final history = _moves(json, 'history');

  // The clock is set before the replay so a won game's time bonus comes out
  // as it did when the game was won (the clock stops at a win).
  final replayed = _replay(
    KlondikeGame.deal(deal, options).tick(Duration(milliseconds: elapsedMs)),
    history,
  );
  final saved = KlondikeGame._(
    dealNumber: deal,
    options: options,
    tableau: tableau,
    stock: stock,
    waste: waste,
    foundations: foundations,
    moveScore: moveScore,
    timeBonus: timeBonus,
    moves: moves,
    elapsedMs: elapsedMs,
    lastDrawCount: lastDrawCount,
    lastDelta: 0,
    winnable: false,
    solution: null,
    previous: null,
    lastUndone: false,
  );
  if (replayed != saved) {
    throw const InvalidDeckError(
      'the saved piles, score or moves do not follow from the saved history',
    );
  }

  var winnable = false;
  List<Move>? solution;
  final winnableField = json['winnable'];
  if (winnableField is bool && winnableField && json.containsKey('solution')) {
    // A saved solution earns `winnable` only by winning again here.
    final line = _moves(json, 'solution');
    try {
      if (_replay(KlondikeGame.deal(deal, options), line).isWon) {
        winnable = true;
        solution = line;
      }
    } on InvalidDeckError {
      winnable = false;
    }
  }
  if (replayed.lastDrawCount != lastDrawCount) {
    throw const InvalidDeckError(
      'lastDrawCount does not follow from the history',
    );
  }
  return replayed._copy(
    lastDelta: 0,
    winnable: winnable,
    solution: solution,
    clearSolution: solution == null,
    lastUndone: lastUndone,
  );
}

SpiderGame _spiderFromJson(Map<String, Object?> json) {
  _checkFormat(json);
  if (_require(json, 'game') != 'spider') {
    throw InvalidValueError('game', 'not a Spider save');
  }
  final deal = DealNumber(
    _int(json, 'deal', min: DealNumber.min, max: DealNumber.max),
  );
  final SpiderOptions options;
  try {
    options = SpiderOptions.fromJson(_map(json, 'options'));
  } on FormatException catch (e) {
    throw InvalidValueError('options', e.message);
  }
  final tableau = _piles(json, 'tableau', spiderColumns);
  final stockRaw = _list(json, 'stock');
  if (stockRaw.length > spiderStockRows) {
    throw InvalidValueError('stock', 'at most $spiderStockRows rows');
  }
  final stock = [
    for (var i = 0; i < stockRaw.length; i++) _pile(stockRaw[i], 'stock[$i]'),
  ];
  for (final row in stock) {
    if (row.length != spiderColumns) {
      throw InvalidDeckError('a stock row must hold $spiderColumns cards');
    }
    for (final card in row) {
      if (card.faceUp) throw InvalidDeckError('the stock holds a face-up card');
    }
  }
  final completedRaw = _list(json, 'completed');
  final completed = <Suit>[];
  for (final s in completedRaw) {
    if (s is! String) throw InvalidValueError('completed', 'suits are letters');
    try {
      completed.add(Suit.fromLetter(s));
    } on FormatException catch (e) {
      throw InvalidValueError('completed', e.message);
    }
  }
  if (completed.length > spiderRunsToWin) {
    throw InvalidDeckError('more than $spiderRunsToWin completed runs');
  }
  _checkDeck(
    [
      for (final c in tableau) ...c,
      for (final r in stock) ...r,
      for (final suit in completed)
        for (var rank = aceRank; rank <= kingRank; rank++) Card(rank, suit),
    ],
    spiderDeck(options.suits),
    'the saved position',
  );
  for (final column in tableau) {
    var seenUp = false;
    for (final card in column) {
      if (card.faceUp) {
        seenUp = true;
      } else if (seenUp) {
        throw InvalidDeckError('a face-down card lies on a face-up one');
      }
    }
  }
  final moveScore = _int(json, 'moveScore', max: 1000000);
  final timeBonus = _int(json, 'timeBonus', max: timeBonusNumerator);
  final moves = _int(json, 'moves');
  final elapsedMs = _int(json, 'elapsedMs', max: _maxElapsedMs);
  final lastUndone = _boolOr(json, 'lastUndone', false);
  final history = _moves(json, 'history');

  final replayed = _replay(
    SpiderGame.deal(deal, options).tick(Duration(milliseconds: elapsedMs)),
    history,
  );
  final saved = SpiderGame._(
    dealNumber: deal,
    options: options,
    tableau: tableau,
    stock: stock,
    completed: completed,
    moveScore: moveScore,
    timeBonus: timeBonus,
    moves: moves,
    elapsedMs: elapsedMs,
    lastDelta: 0,
    previous: null,
    lastUndone: false,
  );
  if (replayed != saved) {
    throw const InvalidDeckError(
      'the saved piles, score or moves do not follow from the saved history',
    );
  }
  return replayed._copy(lastDelta: 0, lastUndone: lastUndone);
}

int _intField(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('"$key" must be an int, not $value');
  return value;
}

/// Decodes any move of either game from its `toJson` form.
Move _moveFromJson(Map<String, Object?> json) {
  final kind = json['kind'];
  switch (kind) {
    case 'run':
      return MoveRun(
        _intField(json, 'from'),
        _intField(json, 'start'),
        _intField(json, 'to'),
      );
    case 'wasteToTableau':
      return WasteToTableau(_intField(json, 'to'));
    case 'wasteToFoundation':
      return const WasteToFoundation();
    case 'tableauToFoundation':
      return TableauToFoundation(_intField(json, 'from'));
    case 'foundationToTableau':
      return FoundationToTableau(
        _intField(json, 'foundation'),
        _intField(json, 'to'),
      );
    case 'draw':
      return const Draw();
    case 'recycle':
      return const Recycle();
    case 'flip':
      return Flip(_intField(json, 'column'));
    case 'move':
      return MoveCards(
        _intField(json, 'from'),
        _intField(json, 'start'),
        _intField(json, 'to'),
      );
    case 'dealRow':
      return const DealRow();
    case 'group':
      final moves = json['moves'];
      if (moves is! List) throw const FormatException('a group needs moves');
      return MoveGroup([
        for (final m in moves)
          if (m is Map)
            _moveFromJson(m.cast<String, Object?>())
          else
            throw FormatException('a move must be an object, not $m'),
      ]);
    default:
      throw FormatException('unknown move kind $kind');
  }
}
