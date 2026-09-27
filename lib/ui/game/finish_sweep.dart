/// The auto-finish sweep (#80): the whole finish is committed at once as one
/// undo step, then its per-step states are shown about 60 ms apart so the
/// cards hop to the foundations one by one, and the win card follows 250 ms
/// after the last.
library;

import 'dart:async';

import 'package:honest_solitaire/engine/finish.dart' as engine;
import 'package:honest_solitaire/engine/game.dart';

const Duration sweepStep = Duration(milliseconds: 60);
const Duration winCardDelay = Duration(milliseconds: 250);

class FinishSweep {
  FinishSweep({required this.show, required this.onDone});

  /// Shows an intermediate state on the board.
  final void Function(Game game) show;

  /// Called once the last step has shown and the win card may appear.
  final void Function() onDone;

  final List<Game> _steps = [];
  int _next = 0;
  Timer? _timer;
  bool _finished = false;

  bool get running => !_finished;

  /// Applies the finish to [game] and returns the final game, or null when
  /// the board cannot be finished. Stepping starts at once.
  KlondikeGame? start(KlondikeGame game) {
    final moves = engine.finishMoves(game);
    final result = engine.applyFinish(game);
    if (result is! Applied<KlondikeGame>) return null;
    Game g = game;
    for (final move in moves) {
      final step = g.apply(move);
      if (step is! Applied<Game>) break;
      g = step.game;
      _steps.add(g);
    }
    _timer = Timer(sweepStep, _tick);
    return result.game;
  }

  void _tick() {
    if (_finished) return;
    if (_next < _steps.length) {
      show(_steps[_next++]);
      _timer = Timer(_next < _steps.length ? sweepStep : winCardDelay, _tick);
    } else {
      _finished = true;
      _timer = null;
      onDone();
    }
  }

  /// Shows the final state now and ends the sweep (pause, back, background).
  void completeNow() {
    if (_finished) return;
    _timer?.cancel();
    _timer = null;
    _finished = true;
    if (_steps.isNotEmpty) show(_steps.last);
    onDone();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _finished = true;
  }
}
