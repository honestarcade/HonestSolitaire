/// The moments of play that make a sound (#101) or a tick (#107). The
/// controller publishes one [FeedbackStep] per action; the feedback layer
/// reduces it to at most one clip and at most one tick.
library;

enum FeedbackEvent {
  /// A new deal, a restart, a setup Deal, a found winnable deal.
  newDeal,

  /// A Spider row dealt from the stock.
  dealRow,

  /// A tableau card turned face up (auto-flip or by hand).
  flip,

  /// A card or run landed: a move, a drop, a draw, a recycle, an undo.
  snap,

  /// A Spider run left the board.
  runCompleted,

  /// A Klondike foundation reached its King.
  foundationCompleted,

  /// The game was won by this step.
  win,

  /// The engine refused the move.
  refused,

  /// A long-press peek started.
  peek,
}

/// What one action did. [sweep] marks a step of the auto-finish sweep,
/// where the Kings' foundations do not chime one by one.
class FeedbackStep {
  const FeedbackStep(this.events, {this.sweep = false});

  final Set<FeedbackEvent> events;
  final bool sweep;

  bool has(FeedbackEvent e) => events.contains(e);

  @override
  String toString() => 'FeedbackStep($events${sweep ? ', sweep' : ''})';
}
