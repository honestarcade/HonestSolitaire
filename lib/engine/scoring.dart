/// The scoring tables — every number the two games score with, as data.
///
/// Klondike (#62): standard, Vegas or none; Spider (#63): one rule set. The
/// time rules are shared: a timed standard Klondike game loses points as
/// the clock runs, and a timed win in either game earns a bonus that falls
/// with the time taken.
library;

/// The New Klondike screen's scoring choice, fixed for the game.
enum ScoringMode { standard, vegas, none }

/// The events Klondike scores.
enum KlondikeScoreEvent {
  /// A card reached a foundation, from the waste or the tableau.
  toFoundation,

  /// A waste card went to the tableau.
  wasteToTableau,

  /// A tableau card turned face up, by auto-flip or by hand.
  flip,

  /// A card came back off a foundation onto the tableau.
  foundationToTableau,

  /// The waste went back to the stock.
  recycle,

  /// The deal itself.
  deal,
}

/// Klondike's rules as a table: mode × event → delta, plus the floor.
class KlondikeScoring {
  const KlondikeScoring._(this.deltas, this.floor);

  final Map<KlondikeScoreEvent, int> deltas;

  /// The lowest the move score may go after one `apply`, or null for none.
  final int? floor;

  int delta(KlondikeScoreEvent event) => deltas[event] ?? 0;

  static const standard = KlondikeScoring._({
    KlondikeScoreEvent.toFoundation: 10,
    KlondikeScoreEvent.wasteToTableau: 5,
    KlondikeScoreEvent.flip: 5,
    KlondikeScoreEvent.foundationToTableau: -15,
    KlondikeScoreEvent.recycle: -2,
    KlondikeScoreEvent.deal: 0,
  }, 0);

  static const vegas = KlondikeScoring._({
    KlondikeScoreEvent.toFoundation: 5,
    KlondikeScoreEvent.wasteToTableau: 0,
    KlondikeScoreEvent.flip: 0,
    KlondikeScoreEvent.foundationToTableau: -5,
    KlondikeScoreEvent.recycle: 0,
    KlondikeScoreEvent.deal: -52,
  }, null);

  static const none = KlondikeScoring._({}, 0);

  static KlondikeScoring of(ScoringMode mode) => switch (mode) {
    ScoringMode.standard => standard,
    ScoringMode.vegas => vegas,
    ScoringMode.none => none,
  };

  /// Timed standard games lose this many points per [timePenaltyPeriod] of
  /// play. Vegas and none never pay it.
  static const int timePenaltyPoints = 2;
  static const Duration timePenaltyPeriod = Duration(seconds: 10);
}

/// Spider's constants (#63).
class SpiderScoring {
  const SpiderScoring._();

  static const int atDeal = 500;
  static const int perMove = -1;
  static const int perRun = 100;

  /// The lowest the move score may go after a move, before run bonuses.
  static const int floor = 0;
}

/// A timed win in either game adds `numerator ÷ seconds`, with the seconds
/// counted as at least [minimumBonusSeconds].
const int timeBonusNumerator = 700000;
const int minimumBonusSeconds = 30;
