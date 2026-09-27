/// The board's piles, as the layout and the controller name them.
///
/// Called `BoardPile` rather than `PileRef` because the engine already
/// exports a `PileRef` for hints; the controller converts between the two.
library;

import 'package:honest_solitaire/engine/card.dart';

sealed class BoardPile {
  const BoardPile();

  /// The token used in widget keys: `stock`, `waste`, `f-spades`, `t3`,
  /// `done2`.
  String get token;
}

class StockPile extends BoardPile {
  const StockPile();

  @override
  String get token => 'stock';

  @override
  bool operator ==(Object other) => other is StockPile;

  @override
  int get hashCode => (StockPile).hashCode;

  @override
  String toString() => 'stock';
}

class WastePile extends BoardPile {
  const WastePile();

  @override
  String get token => 'waste';

  @override
  bool operator ==(Object other) => other is WastePile;

  @override
  int get hashCode => (WastePile).hashCode;

  @override
  String toString() => 'waste';
}

class FoundationPile extends BoardPile {
  const FoundationPile(this.suit);

  final Suit suit;

  @override
  String get token => 'f-${suit.name}';

  @override
  bool operator ==(Object other) =>
      other is FoundationPile && other.suit == suit;

  @override
  int get hashCode => Object.hash(FoundationPile, suit);

  @override
  String toString() => 'foundation(${suit.name})';
}

class TableauPile extends BoardPile {
  const TableauPile(this.column);

  final int column;

  @override
  String get token => 't$column';

  @override
  bool operator ==(Object other) =>
      other is TableauPile && other.column == column;

  @override
  int get hashCode => Object.hash(TableauPile, column);

  @override
  String toString() => 'tableau($column)';
}

/// One of Spider's eight completed-run slots.
class CompletedPile extends BoardPile {
  const CompletedPile(this.slot);

  final int slot;

  @override
  String get token => 'done$slot';

  @override
  bool operator ==(Object other) =>
      other is CompletedPile && other.slot == slot;

  @override
  int get hashCode => Object.hash(CompletedPile, slot);

  @override
  String toString() => 'completed($slot)';
}
