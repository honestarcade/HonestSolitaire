/// The play clock (#78): runs only while the player is actually playing,
/// advancing the engine through `tick` about once a second.
///
/// The clock owns nothing but the part-second not yet handed to the game; the
/// game's `elapsed` is the record. `now` is injectable so tests drive it.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class GameClock extends ChangeNotifier {
  GameClock({Duration Function()? now, required this.onTick})
    : _now = now ?? _stopwatchNow();

  static Duration Function() _stopwatchNow() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  final Duration Function() _now;

  /// Called with the time to add to the game, at whole-second boundaries.
  final void Function(Duration delta) onTick;

  Duration? _startedAt;
  Duration _pending = Duration.zero;
  Timer? _timer;

  /// The game's elapsed when the clock was last synced, for aiming ticks.
  Duration _base = Duration.zero;

  bool get running => _startedAt != null;

  /// Starts (or keeps) running from the game's [elapsed].
  void start(Duration elapsed) {
    if (running) return;
    _base = elapsed;
    _startedAt = _now();
    _schedule();
    notifyListeners();
  }

  void stop() {
    if (!running) return;
    _pending += _now() - _startedAt!;
    _startedAt = null;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Back to waiting for the first move: nothing pending, nothing running.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _pending = Duration.zero;
    _base = Duration.zero;
    notifyListeners();
  }

  /// Hands every unflushed part to the caller (who adds it to the game) and
  /// keeps running from now.
  Duration flush() {
    var out = _pending;
    _pending = Duration.zero;
    if (running) {
      final now = _now();
      out += now - _startedAt!;
      _startedAt = now;
    }
    _base += out;
    return out;
  }

  void _schedule() {
    _timer?.cancel();
    final elapsed =
        _base + _pending + (running ? _now() - _startedAt! : Duration.zero);
    final toBoundary =
        const Duration(seconds: 1) -
        Duration(milliseconds: elapsed.inMilliseconds % 1000);
    _timer = Timer(toBoundary, _fire);
  }

  void _fire() {
    if (!running) return;
    final delta = flush();
    if (delta > Duration.zero) onTick(delta);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
