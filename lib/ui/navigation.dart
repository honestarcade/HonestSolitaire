/// Navigation shared by every M4 screen: the route stack is the menu, at
/// most one board, and the screens opened above it. One [NavigationGuard]
/// ignores a second tap while a push or pop transition runs.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

import 'app.dart';

/// Starts a winnable-deal search; `GameScope.search` holds the app's.
typedef WinnableSearch = DealerHandle Function(
  DealNumber base,
  KlondikeOptions options,
);

DealerHandle defaultWinnableSearch(DealNumber base, KlondikeOptions options) =>
    WinnableDealer.search(base, options);

const boardRouteName = '/board';

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

/// Opens the board on the controller's current game, replacing any board
/// already on the stack.
Future<void>? openBoard(BuildContext context) {
  final scope = GameScope.of(context);
  return scope.navigating.push(
    Navigator.of(context),
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: boardRouteName),
      builder: (_) => const BoardScreen(),
    ),
    toRoot: true,
  );
}
