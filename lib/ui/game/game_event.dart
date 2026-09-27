/// The two game types, and the events the controller emits for statistics
/// and persistence (#84, #85).
library;

import 'package:flutter/foundation.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../../data/app_store.dart';

enum GameType {
  klondike,
  spider;

  static GameType of(Game game) => switch (game) {
    KlondikeGame() => klondike,
    SpiderGame() => spider,
  };

  /// The store document that holds this type's saved game.
  StoreDoc get doc => switch (this) {
    klondike => StoreDoc.gameKlondike,
    spider => StoreDoc.gameSpider,
  };

  GameType get other => this == klondike ? spider : klondike;
}

enum AbandonReason { newDeal, restart }

sealed class GameEvent {
  const GameEvent(this.game);

  final Game game;
}

/// A game with at least one move was replaced by a new one of its type, or
/// restarted: it counts as a loss (#85).
class Abandoned extends GameEvent {
  const Abandoned(super.game, this.reason);

  final AbandonReason reason;
}

/// A game was won (its final state).
class Won extends GameEvent {
  const Won(super.game);
}

/// A `Listenable` that is fired by its owner.
class Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
