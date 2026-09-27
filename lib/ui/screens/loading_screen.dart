/// The loading screen (#87), used twice: at launch, over the app for as long
/// as loading takes; and while a winnable Klondike deal is searched for,
/// with honest progress, a way out, and after the soft limit a choice.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../app.dart';
import '../brand/honest_mark.dart';
import '../card/suit_paths.dart';
import '../format.dart';
import '../game/pause_card.dart';
import '../navigation.dart';
import '../theme/palette.dart';
import '../widgets/screen_header.dart';

/// One step of the launch: the label shown while it runs, and the work.
class LaunchStep {
  const LaunchStep(this.label, this.run);

  final String label;
  final Future<void> Function() run;
}

/// The splash stays at least this long from its first frame.
const splashMinimum = Duration(milliseconds: 600);

/// READY holds this long before the fade.
const splashHold = Duration(milliseconds: 350);
const splashFade = Duration(milliseconds: 200);

/// A load that takes longer than this counts as failed and is skipped.
const launchStepTimeout = Duration(seconds: 5);

/// A search that finds its deal at once still shows the screen this long.
const searchMinimum = Duration(milliseconds: 300);

/// After Keep searching, the choice is offered again at this interval.
const keepSearchingInterval = Duration(seconds: 10);

/// The deals-tried count is announced to screen readers at most this often.
const countAnnounceInterval = Duration(seconds: 2);

const splashGradient = RadialGradient(
  center: Alignment(0, -0.64),
  radius: 1.15,
  colors: [Palette.feltTop, Palette.feltMid, Palette.feltBottom],
  stops: [0, 0.55, 1],
);

enum _Mode { launch, search }

class LoadingScreen extends StatefulWidget {
  /// The launch splash: runs [steps] in order and calls [onDone] when the
  /// fade has finished.
  const LoadingScreen.launch({
    super.key,
    required List<LaunchStep> this.steps,
    required VoidCallback this.onDone,
  }) : _mode = _Mode.launch,
       options = null,
       onGame = null;

  /// The winnable search for [options]; [onGame] runs with the new game
  /// (found, or random instead) just before the board opens on it.
  const LoadingScreen.search({
    super.key,
    required KlondikeOptions this.options,
    this.onGame,
  }) : _mode = _Mode.search,
       steps = null,
       onDone = null;

  final _Mode _mode;
  final List<LaunchStep>? steps;
  final VoidCallback? onDone;
  final KlondikeOptions? options;
  final void Function(KlondikeGame game)? onGame;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  /// Completes when the screen has been shown its minimum time (a timer,
  /// not the wall clock, so tests drive it).
  late final Future<void> _minimumShown = Future<void>.delayed(
    widget._mode == _Mode.launch ? splashMinimum : searchMinimum,
  );

  // Launch.
  int _completed = 0;
  bool _fading = false;

  // Search.
  DealerHandle? _search;
  StreamSubscription<DealerEvent>? _events;
  int? _dealsTried;
  bool _choice = false;
  bool _failed = false;
  bool _ended = false;
  Timer? _reoffer;
  Timer? _announceCooldown;

  @override
  void initState() {
    super.initState();
    _minimumShown;
    if (widget._mode == _Mode.launch) {
      _runLaunch();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
    }
  }

  Future<void> _runLaunch() async {
    for (final step in widget.steps!) {
      try {
        await step.run().timeout(launchStepTimeout);
      } catch (_) {
        // A failing or slow load continues with defaults; the store never
        // throws, and the notice for a quarantined file is #94's.
      }
      if (!mounted) return;
      setState(() => _completed++);
    }
    await _minimumShown;
    await Future<void>.delayed(splashHold);
    if (!mounted) return;
    setState(() => _fading = true);
    await Future<void>.delayed(splashFade);
    if (mounted) widget.onDone!();
  }

  void _startSearch() {
    final scope = GameScope.of(context);
    final base = scope.controller.dealNumberSource();
    final search = scope.search(base, widget.options!);
    _search = search;
    _events = search.events.listen(
      _onEvent,
      onError: (Object _) => _fail(),
      onDone: () {
        if (!_ended && !_failed) _fail();
      },
    );
  }

  void _onEvent(DealerEvent event) {
    if (_ended) return;
    switch (event) {
      case Progress(:final dealsTried):
        setState(() => _dealsTried = dealsTried);
        _announce(dealsTried);
      case SoftLimitReached():
        setState(() => _choice = true);
      case Found(:final game):
        _ended = true;
        _deliver(game);
      case Cancelled():
        break;
      case NotFound():
        _fail();
    }
  }

  void _announce(int dealsTried) {
    if (_announceCooldown?.isActive ?? false) return;
    _announceCooldown = Timer(countAnnounceInterval, () {});
    SemanticsService.sendAnnouncement(
      View.of(context),
      _countText(dealsTried),
      TextDirection.ltr,
    );
  }

  void _fail() {
    if (_ended || !mounted) return;
    setState(() {
      _failed = true;
      _choice = false;
    });
  }

  /// Opens the board on [game] once the minimum showing time has passed;
  /// Cancel in the meantime still wins.
  Future<void> _deliver(KlondikeGame game) async {
    _reoffer?.cancel();
    await _minimumShown;
    if (!mounted || _cancelled) return;
    final scope = GameScope.of(context);
    widget.onGame?.call(game);
    scope.controller.replaceGame(game);
    openBoard(context);
  }

  bool _cancelled = false;

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _ended = true;
    _reoffer?.cancel();
    _search?.cancel();
    Navigator.of(context).pop();
  }

  void _keepSearching() {
    setState(() => _choice = false);
    _reoffer?.cancel();
    _reoffer = Timer(keepSearchingInterval, () {
      if (mounted && !_ended && !_failed) setState(() => _choice = true);
    });
  }

  /// A fresh random deal with the same options, never silently: the label
  /// said what was happening and the player chose this.
  void _randomInstead() {
    if (_cancelled) return;
    _ended = true;
    _reoffer?.cancel();
    _search?.cancel();
    final scope = GameScope.of(context);
    var number = scope.controller.dealNumberSource();
    if (number == scope.controller.game.dealNumber) {
      number = scope.controller.dealNumberSource();
    }
    final game = KlondikeGame.deal(number, widget.options!);
    widget.onGame?.call(game);
    scope.controller.replaceGame(game);
    openBoard(context);
  }

  @override
  void dispose() {
    _events?.cancel();
    _reoffer?.cancel();
    _announceCooldown?.cancel();
    if (!_ended) _search?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = screenScale(context);
    final launch = widget._mode == _Mode.launch;
    final steps = widget.steps;
    final label = launch
        ? (_completed < steps!.length
              ? steps[_completed].label
              : steps.last.label)
        : (_failed ? 'No winnable deal found' : 'FINDING A WINNABLE DEAL');
    final body = Semantics(
      label: launch ? 'Loading Honest Solitaire' : null,
      container: launch,
      excludeSemantics: launch,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: splashGradient),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Mark(size: 132 * s),
              SizedBox(height: 30 * s),
              _Title(scale: s),
              SizedBox(height: 30 * s),
              LoadingBar(
                key: const Key('loading-bar'),
                width: 220 * s,
                fraction: launch ? _completed / steps!.length : null,
                running: !launch && !_failed,
              ),
              SizedBox(height: 30 * s),
              Text(
                label,
                key: const Key('loading-label'),
                style: TextStyle(
                  fontSize: 10 * s,
                  height: 1,
                  letterSpacing: 2 * s,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5C7FB0),
                ),
              ),
              if (!launch) ...[
                SizedBox(height: 14 * s),
                Text(
                  _dealsTried == null ? '' : _countText(_dealsTried!),
                  key: const Key('loading-count'),
                  style: TextStyle(
                    fontSize: 10 * s,
                    height: 1,
                    letterSpacing: 2 * s,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5C7FB0).withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 26 * s),
                SizedBox(width: 220 * s, child: _actions(s)),
              ],
            ],
          ),
        ),
      ),
    );
    if (launch) {
      return AnimatedOpacity(
        opacity: _fading ? 0 : 1,
        duration: splashFade,
        child: body,
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: body,
    );
  }

  Widget _actions(double s) {
    if (_failed) {
      return Column(
        children: [
          CardButton.primary(
            'Deal a random game instead',
            key: const Key('loading-random'),
            onPressed: _randomInstead,
            scale: s,
          ),
          SizedBox(height: 10 * s),
          CardButton.secondary(
            'Back',
            key: const Key('loading-back'),
            onPressed: _cancel,
            scale: s,
          ),
        ],
      );
    }
    if (_choice) {
      return Column(
        children: [
          Text(
            'No winnable deal yet',
            key: const Key('loading-choice'),
            style: TextStyle(
              fontSize: 12.5 * s,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1,
            ),
          ),
          SizedBox(height: 12 * s),
          CardButton.primary(
            'Keep searching',
            key: const Key('loading-keep'),
            onPressed: _keepSearching,
            scale: s,
          ),
          SizedBox(height: 10 * s),
          CardButton.secondary(
            'Deal a random game instead',
            key: const Key('loading-random'),
            onPressed: _randomInstead,
            scale: s,
          ),
        ],
      );
    }
    return CardButton.secondary(
      'Cancel',
      key: const Key('loading-cancel'),
      onPressed: _cancel,
      scale: s,
    );
  }
}

String _countText(int n) =>
    '${formatCount(n)} ${n == 1 ? 'deal' : 'deals'} tried';

/// The mark with the brand spade: teal, 44 % of the box, centred 8 % below
/// the middle (planner's discretion, #87).
class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: const HonestMarkPainter(strokeScale: 0.75),
      foregroundPainter: _SpadePainter(),
    ),
  );
}

class _SpadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final box = size.width * 0.44;
    final origin = Offset(
      (size.width - box) / 2,
      (size.height - box) / 2 + size.height * 0.08,
    );
    canvas.drawPath(
      suitPathAt(Suit.spades, origin, box),
      Paint()..color = Palette.teal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Title extends StatelessWidget {
  const _Title({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Column(
      children: [
        Text.rich(
          TextSpan(
            text: 'Honest',
            children: const [
              TextSpan(
                text: 'Solitaire',
                style: TextStyle(color: Palette.teal),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 40 * s,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2 * s,
            color: Colors.white,
            height: 1,
          ),
        ),
        SizedBox(height: 14 * s),
        Text(
          'BY HONEST ARCADE',
          style: TextStyle(
            fontSize: 11 * s,
            height: 1,
            letterSpacing: 3.08 * s,
            fontWeight: FontWeight.w500,
            color: Palette.mist,
          ),
        ),
      ],
    );
  }
}

/// The teal→blue bar: determinate ([fraction], tweened over 200 ms and
/// retargeted to the latest value) or indeterminate (a 30 %-wide segment
/// looping every 1.2 s ease-in-out while [running]).
class LoadingBar extends StatefulWidget {
  const LoadingBar({
    super.key,
    required this.width,
    this.fraction,
    this.running = true,
  });

  final double width;

  /// The target fill, 0..1; null means indeterminate.
  final double? fraction;
  final bool running;

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fill;

  @override
  void initState() {
    super.initState();
    if (widget.fraction == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      _fill = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
      if (widget.running) _controller.repeat();
    } else {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: 1,
      );
      _fill = Tween(
        begin: widget.fraction,
        end: widget.fraction,
      ).animate(_controller);
    }
  }

  @override
  void didUpdateWidget(LoadingBar old) {
    super.didUpdateWidget(old);
    final target = widget.fraction;
    if (target != null && target != old.fraction) {
      _fill = Tween(begin: _fill.value, end: target).animate(_controller);
      _controller.forward(from: 0);
    }
    if (target == null && widget.running != old.running) {
      if (widget.running) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: Container(
      width: widget.width,
      height: 5,
      color: const Color(0x1FFFFFFF),
      child: AnimatedBuilder(
        animation: _fill,
        builder: (context, _) {
          final indeterminate = widget.fraction == null;
          final segment = indeterminate ? 0.3 : _fill.value.clamp(0.0, 1.0);
          final left = indeterminate
              ? _fill.value * (1 - 0.3) * widget.width
              : 0.0;
          return Stack(
            children: [
              Positioned(
                left: left,
                top: 0,
                bottom: 0,
                width: segment * widget.width,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    gradient: LinearGradient(
                      colors: [Palette.teal, Palette.blue],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
