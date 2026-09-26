/// The engine's shared game model: the sealed `Game` and `Move` supertypes,
/// the `Applied`/`Refused` result of a move, and the refusal reasons both
/// games share.
///
/// Klondike, Spider, the undo history, serialization and the winnable dealer
/// are `part`s of this library rather than libraries of their own, for one
/// reason: `Game` and `Move` are sealed (so a `switch` over them is
/// exhaustive), and Dart only lets a sealed type's subtypes live in the same
/// library. The parts also share the library-private constructor that is the
/// only way to mark a Klondike game `winnable` (#68).
///
/// Everything here is pure Dart; `test/guards/engine_imports_test.dart`
/// keeps it that way.
library;

import 'card.dart';
import 'deal_number.dart';
import 'deck.dart';
import 'rng.dart';
import 'scoring.dart';

part 'history.dart';
part 'klondike.dart';
part 'spider.dart';
part 'serialization.dart';
part 'winnable_dealer.dart';

/// Why a move was refused. One reason per rule, shared by both games.
enum RefusalReason {
  /// The game is already won; nothing more can be applied.
  gameOver,

  /// The move names a pile or index that does not exist, or the same source
  /// and target, or a kind the game does not know.
  invalidMove,

  /// The card to move, or the card it would land on, is face down.
  notFaceUp,

  /// Klondike: the cards from the start index up are not an alternating
  /// descending run.
  notAlternatingRun,

  /// Spider: the cards from the start index up are not a same-suit
  /// descending run.
  notSameSuitRun,

  /// Klondike tableau: the moving card is the same colour as the target.
  colourMismatch,

  /// The moving card is not one rank below the target's top card.
  rankMismatch,

  /// Klondike: only a king (or a run headed by one) goes on an empty column.
  emptyColumnNeedsKing,

  /// A foundation takes only its suit's ace, then the next rank of that
  /// suit.
  foundationRankMismatch,

  /// Klondike: the source pile (waste, foundation, column) is empty.
  emptySource,

  /// Nothing to draw or deal: the stock is empty.
  stockEmpty,

  /// Klondike: the waste cannot be recycled while the stock still has cards.
  stockNotEmpty,

  /// Klondike: the waste is empty, so there is nothing to recycle.
  wasteEmpty,

  /// A manual flip is only legal on a face-down top card while auto-flip is
  /// off.
  flipNotAllowed,

  /// Spider, strict rule: a row cannot be dealt while a column is empty.
  emptyColumnStrict,

  /// Undo: nothing to undo, or the setting forbids undoing this move.
  cannotUndo,

  /// Auto-finish: the board cannot be finished from here.
  cannotFinish,
}

/// Which pile a card came from or went to, for scoring and animation.
enum PileKind { tableau, foundation, waste, stock, completed }

/// What an applied move did, beyond the new state: the facts scoring reads
/// (#62, #63) and the board animates (M5).
class Effects {
  const Effects({
    this.from,
    this.to,
    this.cardsMoved = 0,
    this.cardsFlipped = 0,
    this.cardsDrawn = 0,
    this.recycled = false,
    this.rowDealt = false,
    this.runsCompleted = const [],
    this.steps = const [],
  });

  static const none = Effects();

  final PileKind? from;
  final PileKind? to;

  /// Cards moved by the player's own move (a run counts each card).
  final int cardsMoved;

  /// Cards turned face up, whether by auto-flip or by a `Flip` move.
  final int cardsFlipped;

  /// Cards turned onto the waste by a draw.
  final int cardsDrawn;

  /// The waste went back to the stock.
  final bool recycled;

  /// Spider: a row of ten was dealt.
  final bool rowDealt;

  /// Spider: the suits of runs that left the board, in completion order.
  final List<Suit> runsCompleted;

  /// For a grouped apply (undo, auto-finish): the per-step effects, in order.
  final List<Effects> steps;

  Effects merge(Effects other) => Effects(
    from: from ?? other.from,
    to: to ?? other.to,
    cardsMoved: cardsMoved + other.cardsMoved,
    cardsFlipped: cardsFlipped + other.cardsFlipped,
    cardsDrawn: cardsDrawn + other.cardsDrawn,
    recycled: recycled || other.recycled,
    rowDealt: rowDealt || other.rowDealt,
    runsCompleted: [...runsCompleted, ...other.runsCompleted],
    steps: [...steps, ...other.steps],
  );
}

/// The outcome of `apply`, `undo` or `applyFinish`: a new game with what
/// happened, or a typed refusal. Neither throws for an illegal move.
sealed class ApplyResult<G extends Game> {
  const ApplyResult();
}

class Applied<G extends Game> extends ApplyResult<G> {
  const Applied(this.game, this.effects);

  final G game;
  final Effects effects;
}

class Refused<G extends Game> extends ApplyResult<G> {
  const Refused(this.reason);

  final RefusalReason reason;

  @override
  String toString() => 'Refused($reason)';
}

/// A player's move in either game.
sealed class Move {
  const Move();

  /// Compact JSON for saved games (#69) and the solver's lines (#66).
  Map<String, Object?> toJson();
}

/// A game of either kind, immutable: every operation returns a new game.
sealed class Game {
  const Game();

  DealNumber get dealNumber;

  /// The score as shown: the move score, the time penalty where the rules
  /// have one, and the win bonus.
  int get score;

  /// Applied player moves; auto-flips, run removals and refusals count 0.
  int get moves;

  /// Play time so far. The engine never reads a clock: the UI calls [tick].
  Duration get elapsed;

  /// The bonus a fast timed win added to [score], 0 until then.
  int get timeBonus;

  /// The change the last `apply` made to [score] after any floor; 0 after a
  /// deal, undo, restart or tick.
  int get lastDelta;

  bool get isWon;

  List<Move> legalMoves();

  ApplyResult<Game> apply(Move move);

  /// The same game with [duration] added to [elapsed]; ignored once won.
  Game tick(Duration duration);

  bool canUndo({required bool unlimited});

  ApplyResult<Game> undo({required bool unlimited});

  Game restart();

  /// Undo steps back to the deal.
  int get historyLength => _historyLength(this);

  /// Every move applied since the deal, oldest first.
  List<Move> get historyMoves => _historyMoves(this);

  HistoryEntry? get _previous;

  bool get _lastUndone;

  Map<String, Object?> toJson();

  /// Dispatches on the saved `"game"` field to the right game's `fromJson`.
  static Game fromJson(Map<String, Object?> json) => _gameFromJson(json);
}

/// The shared time rules: seconds are truncated from milliseconds, then the
/// minimum applies, then the bonus is the integer division.
int winTimeBonus(Duration elapsed) {
  var seconds = elapsed.inMilliseconds ~/ 1000;
  if (seconds < minimumBonusSeconds) seconds = minimumBonusSeconds;
  return timeBonusNumerator ~/ seconds;
}

List<T> _fixed<T>(Iterable<T> items) => List<T>.unmodifiable(items);

List<List<Card>> _fixedPiles(Iterable<List<Card>> piles) =>
    List<List<Card>>.unmodifiable(piles.map(_fixed));

bool _sameCards(List<Card> a, List<Card> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _samePiles(List<List<Card>> a, List<List<Card>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_sameCards(a[i], b[i])) return false;
  }
  return true;
}

int _hashCards(List<Card> cards) => Object.hashAll(cards);

int _hashPiles(List<List<Card>> piles) => Object.hashAll(piles.map(_hashCards));
