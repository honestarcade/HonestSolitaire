part of 'game.dart';

/// What a winnable search reports, in order: `Progress` events, at most one
/// `SoftLimitReached`, then exactly one of `Found`, `NotFound` or
/// `Cancelled`, after which the stream closes.
sealed class DealerEvent {
  const DealerEvent();
}

class Progress extends DealerEvent {
  const Progress(this.dealsTried, this.elapsed);

  /// Deal numbers tried so far, the found one included.
  final int dealsTried;
  final Duration elapsed;

  @override
  String toString() =>
      'Progress($dealsTried deals, ${elapsed.inMilliseconds} ms)';
}

/// The soft limit passed while the search continues; M4's loading screen
/// offers "Keep searching" or "Deal a random game instead" (owner,
/// /n8-plan M2 round one: about 5 s).
class SoftLimitReached extends DealerEvent {
  const SoftLimitReached();
}

/// A deal proven winnable on this device: [game] carries `winnable: true`
/// and [solution], replayed here from the deal before this was emitted.
class Found extends DealerEvent {
  const Found(this.game, this.solution);

  final KlondikeGame game;
  final List<Move> solution;

  @override
  String toString() =>
      'Found(#${game.dealNumber.value}, ${solution.length} moves)';
}

class Cancelled extends DealerEvent {
  const Cancelled();
}

/// Every deal number was tried once and none was proven winnable.
class NotFound extends DealerEvent {
  const NotFound();
}

/// A running search: a single-subscription [events] stream and [cancel].
class DealerSearch {
  DealerSearch._(this._base, this._options, this._nodeBudget, this._softLimit);

  final DealNumber _base;
  final KlondikeOptions _options;
  final int _nodeBudget;
  final Duration? _softLimit;

  final _controller = StreamController<DealerEvent>();
  final _port = ReceivePort();
  final _watch = Stopwatch();
  Isolate? _isolate;
  Timer? _softTimer;
  bool _done = false;
  bool _progressed = false;
  int _lastProgressMs = -1000;
  int _dealsTried = 0;

  Stream<DealerEvent> get events => _controller.stream;

  /// Stops the isolate at once and yields `Cancelled`; nothing follows. A
  /// no-op after a terminal event.
  Future<void> cancel() async {
    if (_done) return;
    _finish(const Cancelled());
  }

  Future<void> _start() async {
    _watch.start();
    if (_softLimit != null) {
      _softTimer = Timer(_softLimit, () {
        if (_done) return;
        if (!_progressed) _emitProgress(force: true);
        _controller.add(const SoftLimitReached());
      });
    }
    _port.listen(_onMessage);
    try {
      _isolate = await Isolate.spawn(
        _worker,
        _WorkerArgs(
          _port.sendPort,
          _base.value,
          _options.toJson(),
          _nodeBudget,
        ),
        errorsAreFatal: true,
        onError: _port.sendPort,
      );
    } on Object catch (error, stack) {
      if (!_done) {
        _controller.addError(error, stack);
        _finish(null);
      }
    }
  }

  void _onMessage(Object? message) {
    if (_done) return;
    if (message is List && message.isNotEmpty && message.first == 'p') {
      _dealsTried = message[1] as int;
      _emitProgress();
    } else if (message is List && message.isNotEmpty && message.first == 'f') {
      _dealsTried = message[1] as int;
      final number = DealNumber(message[2] as int);
      final json = (message[3] as List).cast<Map<String, Object?>>();
      _emitProgress(force: true);
      _verifyAndEmit(number, json);
    } else if (message is List && message.isNotEmpty && message.first == 'n') {
      _dealsTried = message[1] as int;
      _emitProgress(force: true);
      _finish(const NotFound());
    } else {
      // An uncaught error in the worker arrives as [message, stackTrace].
      _controller.addError(
        StateError('winnable search failed: $message'),
        StackTrace.current,
      );
      _finish(null);
    }
  }

  void _emitProgress({bool force = false}) {
    final ms = _watch.elapsedMilliseconds;
    // At most ten a second, so a fast search does not flood the screen.
    if (!force && ms - _lastProgressMs < 100) return;
    _lastProgressMs = ms;
    _progressed = true;
    _controller.add(Progress(_dealsTried, _watch.elapsed));
  }

  /// The second honesty check: re-deal the number here and replay the
  /// worker's line through `apply` before anything is marked winnable.
  void _verifyAndEmit(DealNumber number, List<Map<String, Object?>> json) {
    try {
      final moves = [for (final m in json) Move.fromJson(m)];
      final deal = KlondikeGame.deal(number, _options);
      var g = deal;
      for (final move in moves) {
        final result = g.apply(move);
        if (result is! Applied<KlondikeGame>) {
          throw StateError('the solution was refused at $move');
        }
        g = result.game;
      }
      if (!g.isWon) throw StateError('the solution did not win');
      final proven = deal._copy(winnable: true, solution: moves);
      _finish(Found(proven, proven.solution!));
    } on Object catch (error, stack) {
      _controller.addError(error, stack);
      _finish(null);
    }
  }

  void _finish(DealerEvent? terminal) {
    if (_done) return;
    _done = true;
    _softTimer?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port.close();
    if (terminal != null) _controller.add(terminal);
    _controller.close();
  }
}

class _WorkerArgs {
  const _WorkerArgs(this.port, this.base, this.options, this.nodeBudget);

  final SendPort port;
  final int base;
  final Map<String, Object?> options;
  final int nodeBudget;
}

/// Runs in the worker isolate: tries base, base+1, … wrapping within the
/// deal-number range, at the solver's budget, and reports the first proven
/// deal as its number plus the solution's JSON.
void _worker(_WorkerArgs args) {
  final options = KlondikeOptions.fromJson(args.options);
  var number = DealNumber(args.base);
  final span = DealNumber.max - DealNumber.min + 1;
  for (var tried = 1; tried <= span; tried++) {
    final result = solve(
      KlondikeGame.deal(number, options),
      nodeBudget: args.nodeBudget,
    );
    if (result is Solved) {
      args.port.send([
        'f',
        tried,
        number.value,
        [for (final m in result.moves) m.toJson()],
      ]);
      return;
    }
    args.port.send(['p', tried]);
    number = number.next;
  }
  args.port.send(['n', span]);
}

/// Finds a Klondike deal the solver proves winnable, off the UI thread.
class WinnableDealer {
  const WinnableDealer._();

  /// Starts a search from [base] (base, base+1, … wrapping in 1..999999) so a
  /// given base always yields the same winnable deal number. [softLimit]
  /// null disables the `SoftLimitReached` event.
  static DealerSearch search(
    DealNumber base,
    KlondikeOptions options, {
    Duration? softLimit = const Duration(seconds: 5),
    int nodeBudget = defaultNodeBudget,
  }) {
    if (nodeBudget <= 0) {
      throw ArgumentError.value(nodeBudget, 'nodeBudget', 'must be > 0');
    }
    final search = DealerSearch._(base, options, nodeBudget, softLimit);
    search._start();
    return search;
  }
}
