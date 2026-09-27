/// Navigation shared by every M4 screen: the route stack is the menu, at
/// most one board, and the screens opened above it. One [NavigationGuard]
/// ignores a second tap while a push or pop transition runs.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

import 'app.dart';
import 'game/game_event.dart';
import 'screens/new_klondike_screen.dart';
import 'screens/new_spider_screen.dart';

/// Starts a winnable-deal search; `GameScope.search` holds the app's.
typedef WinnableSearch = DealerHandle Function(
  DealNumber base,
  KlondikeOptions options,
);

DealerHandle defaultWinnableSearch(DealNumber base, KlondikeOptions options) =>
    WinnableDealer.search(base, options);

const boardRouteName = '/board';

/// The menu is the app's home route (#94).
const menuRouteName = '/';

/// Tells the board when it is the visible route (#101's music gate).
final RouteObserver<ModalRoute<void>> boardRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Ignores navigation while a route transition runs; the flag clears when
/// the transition's animation settles (#87, common conventions).
class NavigationGuard {
  bool _busy = false;
  bool get busy => _busy;

  /// Pushes [route], or returns null while a transition runs. [toRoot]
  /// removes everything above the first route (a new board replaces
  /// whatever board exists, so back from any board is the menu).
  Future<T?>? push<T>(
    NavigatorState navigator,
    Route<T> route, {
    bool toRoot = false,
  }) {
    if (_busy) return null;
    final result = toRoot
        ? navigator.pushAndRemoveUntil(route, (r) => r.isFirst)
        : navigator.push(route);
    _lock(route);
    return result;
  }

  /// Pops the caller's route unless a transition runs.
  bool pop(BuildContext context, [Object? result]) {
    if (_busy) return false;
    final route = ModalRoute.of(context);
    Navigator.of(context).pop(result);
    if (route != null) _lock(route);
    return true;
  }

  /// Marks a transition started by someone else (a `popUntil`).
  void lockOn(Route<Object?> route) => _lock(route);

  void _lock(Route<Object?> route) {
    final animation = route is TransitionRoute ? route.animation : null;
    if (animation == null ||
        animation.status == AnimationStatus.completed ||
        animation.status == AnimationStatus.dismissed) {
      // A pop starts from `completed`; wait for the reverse to finish. A
      // push starts from `dismissed` and moves at the next frame.
      if (animation == null) return;
    }
    _busy = true;
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        _busy = false;
      }
    }

    animation.addStatusListener(listener);
  }
}

/// The board route; pushed only with a game on the controller.
Route<void> boardRoute() => MaterialPageRoute<void>(
  settings: const RouteSettings(name: boardRouteName),
  builder: (_) => const BoardScreen(),
);

/// Opens the board on the controller's current game, replacing any board
/// already on the stack.
Future<void>? openBoard(BuildContext context) {
  final scope = GameScope.of(context);
  return scope.navigating.push(
    Navigator.of(context),
    boardRoute(),
    toRoot: true,
  );
}

/// Whether a board route sits somewhere in the stack (the launch root
/// today, a named board route once #94 makes the menu the root).
bool hasBoardBelow(NavigatorState navigator) {
  var found = false;
  navigator.popUntil((route) {
    if (route.settings.name == boardRouteName || route.isFirst) found = true;
    return true;
  });
  return found;
}

/// The game a setup screen's "Keep playing" would return to: the
/// controller's live game of [type] when it has a move, else the saved
/// slot when it is resumable. Null hides the button.
Game? keepPlayingTarget(GameScope scope, GameType type) {
  final live = scope.controller.game;
  if (GameType.of(live) == type) {
    return scope.controller.hasMove && !live.isWon ? live : null;
  }
  final slot = scope.saves.value[type];
  return slot != null && slot.resumable ? slot.game : null;
}

/// Starts [game] from a setup screen: the saved game of its type that is
/// not the live one has its loss recorded once (#85); the live one is the
/// controller's own event. Then the board opens on it.
Future<void> startNewGame(BuildContext context, Game game) async {
  final scope = GameScope.of(context);
  if (scope.navigating.busy) return;
  final type = GameType.of(game);
  final abandon = scope.statsListener.abandonSaved(type);
  scope.controller.replaceGame(game);
  switch (game) {
    case KlondikeGame k:
      scope.settingsStore.setLastKlondikeOptions(k.options);
    case SpiderGame s:
      scope.settingsStore.setLastSpiderOptions(s.options);
  }
  openBoard(context);
  await abandon;
}

/// Resumes [target] (from [keepPlayingTarget]): the live game is unpaused
/// and its board below is returned to; a saved game is installed on a new
/// board, recording nothing.
void keepPlaying(BuildContext context, Game target) {
  final scope = GameScope.of(context);
  if (scope.navigating.busy) return;
  final navigator = Navigator.of(context);
  if (identical(scope.controller.game, target) ||
      scope.controller.game == target) {
    scope.controller.resume();
    if (hasBoardBelow(navigator)) {
      final route = ModalRoute.of(context);
      navigator.popUntil((r) => r.settings.name == boardRouteName || r.isFirst);
      if (route != null) scope.navigating.lockOn(route);
      return;
    }
  } else {
    final slot = scope.saves.value[GameType.of(target)];
    scope.controller.resumeGame(target, hasMove: slot?.start ?? true);
  }
  openBoard(context);
}

/// A fresh random number, rerolled once if it equals [current].
DealNumber freshDealNumber(GameScope scope, DealNumber? current) {
  var number = scope.controller.dealNumberSource();
  if (number == current) number = scope.controller.dealNumberSource();
  return number;
}

/// Opens [screen] above the current route. From the board the game is
/// paused first, so returning shows the pause card (common conventions).
Future<void>? openScreen(BuildContext context, Widget screen) {
  final scope = GameScope.of(context);
  if (scope.navigating.busy) return null;
  final onBoard = ModalRoute.of(context)?.settings.name == boardRouteName;
  if (onBoard) scope.controller.pause();
  return scope.navigating.push(
    Navigator.of(context),
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

/// NEW, a card's New deal: the setup screen for [type] (owner, round one).
Future<void>? openSetup(BuildContext context, GameType type) => openScreen(
  context,
  type == GameType.klondike
      ? const NewKlondikeScreen()
      : const NewSpiderScreen(),
);

/// Main menu from the pause or win card: the save is flushed and the stack
/// pops to the menu; the controller keeps its game (paused, or won), so
/// nothing is recorded and Continue can offer it.
void goToMenu(BuildContext context) {
  final scope = GameScope.of(context);
  if (scope.navigating.busy) return;
  scope.persistence.flush();
  final route = ModalRoute.of(context);
  Navigator.of(context).popUntil((r) => r.isFirst);
  if (route != null) scope.navigating.lockOn(route);
}

/// The menu's Continue: the controller's live game when it is the saved
/// one (unpaused), else the saved game installed with `resumeGame`; then
/// the board.
void continueGame(BuildContext context) {
  final scope = GameScope.of(context);
  if (scope.navigating.busy) return;
  final slot = scope.saves.value.resumeTarget;
  if (slot == null) return;
  final live = scope.controller.game;
  if (live == slot.game) {
    scope.controller.resume();
  } else {
    scope.controller.resumeGame(slot.game, hasMove: slot.start);
  }
  openBoard(context);
}
