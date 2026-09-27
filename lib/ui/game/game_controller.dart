/// The board's state and its tap rules: the current game, the settings,
/// the selection, the active hint, the shake target (#74) and every tap a
/// player can make (#75 Klondike, #76 Spider). Every move goes through the
/// engine's `apply`; the controller never changes a pile itself.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/finish.dart' as engine;
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart' as engine;

import '../board/pile_ref.dart';
import '../settings/display_options.dart';
import '../settings/play_settings.dart';
import 'finish_sweep.dart';
import 'game_clock.dart';
import 'game_event.dart';
import 'ui_hint.dart';
import '../board/card_motion.dart';
import '../../feedback/feedback_event.dart';

/// A run to shake sideways: the pile, the first card of the run, and a
/// sequence number so a repeat restarts the animation.
class ShakeTarget {
  const ShakeTarget(this.pile, this.start, this.sequence);

  final BoardPile pile;
  final int? start;
  final int sequence;

  @override
  bool operator ==(Object other) =>
      other is ShakeTarget &&
      other.pile == pile &&
      other.start == start &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(pile, start, sequence);
}

/// How long a refused move shakes (#75).
const Duration shakeDuration = Duration(milliseconds: 300);

/// Two taps on the same card within this window are a double-tap.
const Duration doubleTapWindow = Duration(milliseconds: 300);

/// A Spider stock tap this soon after a deal is ignored, so two rows are
/// never dealt by accident (owner, /n8-plan M3 gate default).
const Duration dealDebounce = Duration(milliseconds: 300);

/// An illegal drop slides home over this long (#77).
const Duration springBackDuration = Duration(milliseconds: 200);

/// A run being dragged (#77).
class DragState {
  const DragState({
    required this.pile,
    required this.start,
    required this.cards,
    required this.homeRects,
    required this.grabOffset,
    required this.position,
    required this.targets,
  });

  final BoardPile pile;
  final int start;
  final List<Card> cards;

  /// Where the cards sat when lifted, in board coordinates.
  final List<Rect> homeRects;

  /// Finger position minus the first card's origin at lift.
  final Offset grabOffset;

  /// The finger now, in board coordinates.
  final Offset position;

  /// Piles that accept the run (the own-suit foundation only, in Klondike).
  final Set<BoardPile> targets;

  /// The first card's origin now.
  Offset get origin => position - grabOffset;

  /// Every card's rect now, keeping the run's fan.
  List<Rect> get rects => [
    for (final r in homeRects) r.shift(origin - homeRects.first.topLeft),
  ];

  DragState moved(Offset to) => DragState(
    pile: pile,
    start: start,
    cards: cards,
    homeRects: homeRects,
    grabOffset: grabOffset,
    position: to,
    targets: targets,
  );
}

/// A run sliding home after an illegal drop.
class SpringBack {
  const SpringBack({
    required this.pile,
    required this.start,
    required this.cards,
    required this.from,
    required this.to,
    required this.sequence,
  });

  final BoardPile pile;
  final int start;
  final List<Card> cards;
  final List<Rect> from;
  final List<Rect> to;
  final int sequence;
}

class GameController extends ChangeNotifier {
  GameController(
    Game game,
    this.playSettings,
    this.displayOptions, {
    DealNumber Function()? dealNumberSource,
    Duration Function()? clockNow,
    bool observeLifecycle = true,
  }) : _game = game,
       displayGame = GameNotifier(game),
       dealNumberSource = dealNumberSource ?? DealNumber.random {
    playSettings.addListener(_onSettings);
    clock = GameClock(now: clockNow, onTick: _onClockTick);
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    }
  }

  /// Fired on every committed change to the game — moves, undo, restart, a
  /// new or resumed deal — never for selection, hints, pause or clock ticks.
  /// Persistence saves on it (#84).
  final Signal gameChanged = Signal();

  /// Typed events for statistics (#85): a game abandoned or won.
  final ValueNotifier<GameEvent?> events = ValueNotifier(null);

  /// Whether the current game has ever had a move applied — sticky across
  /// undo back to the deal, restored from a saved game on resume. Distinct
  /// from the clock's first-move gate.
  bool _hasMove = false;
  bool get hasMove => _hasMove;

  /// The game as the top bar shows it: updated on every change, clock ticks
  /// included, without notifying the board. (A plain `ValueNotifier` would
  /// stay silent on a tick, because game equality ignores the clock.)
  final GameNotifier displayGame;

  late final GameClock clock;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _paused = false;

  /// Whether the player has made a move since the deal: the clock waits for
  /// the first one (owner, /n8-plan M3 round one).
  bool _moved = false;

  bool get isPaused => _paused;

  FinishSweep? _sweep;
  Game? _shownStep;
  bool _winShown = false;
  Timer? _winTimer;

  /// The other game, kept while the player is on this one (owner, /n8-plan
  /// M3 round two: switching back resumes it).

  /// The last Klondike options seen, for "Switch to Klondike".

  /// Whether a finish sweep is stepping: every input is blocked meanwhile.
  bool get finishing => _sweep != null;

  /// The game the board paints: a sweep's current step, else the game.
  Game get shown => _shownStep ?? _game;

  /// The win card is up (250 ms after the winning move or the sweep's last
  /// step).
  bool get winShown => _winShown;

  /// Stops the clock and the gestures and shows the pause card (#80). A
  /// sweep in progress completes first, and the win card wins.
  void pause() {
    if (_paused) return;
    _sweep?.completeNow();
    if (_game.isWon) return;
    _paused = true;
    _dragging = null;
    _peekColumn = null;
    _syncClock();
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _syncClock();
    notifyListeners();
  }

  /// System back: on the board pauses, on the pause card resumes, on the win
  /// card does nothing.
  void back() {
    if (_winShown) return;
    if (_sweep != null) {
      _sweep!.completeNow();
      return;
    }
    if (_paused) {
      resume();
    } else {
      pause();
    }
  }

  bool _pauseOnReturn = false;

  void _onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _sweep?.completeNow();
      if (_moved && !_game.isWon) _pauseOnReturn = true;
    }
    if (_foreground && _pauseOnReturn) {
      _pauseOnReturn = false;
      pause();
    }
    _syncClock();
  }

  /// Starts the finish sweep over [game] (already checked with canFinish).
  void _startSweep(KlondikeGame game) {
    _hint = null;
    _selection = null;
    _dragging = null;
    _peekColumn = null;
    _flushClock();
    final sweep = FinishSweep(
      show: (step) {
        final before = _shownStep ?? _game;
        _shownStep = step;
        displayGame.value = step;
        // Each step lands a card; the Kings do not chime inside the sweep
        // (the win chimes at the end).
        _emit({
          ...deriveFeedback(before, step),
          FeedbackEvent.snap,
        }, sweep: true);
        notifyListeners();
      },
      onDone: () {
        _sweep = null;
        _shownStep = null;
        displayGame.value = _game;
        _showWin();
      },
    );
    final result = sweep.start(game);
    if (result == null) {
      assert(false, 'canFinish was true but the sweep did not apply');
      return;
    }
    _sweep = sweep;
    _shownStep = game;
    // Committed now: the clock stops here, so the time bonus uses this
    // moment; the board shows the steps.
    _game = result;
    _moved = true;
    _syncClock();
    displayGame.value = game;
    notifyListeners();
    // No animations: the steps are not shown one by one (#99).
    if (motion == AppMotion.none) sweep.completeNow();
  }

  void _showWin() {
    _winTimer?.cancel();
    _winTimer = null;
    _winShown = true;
    notifyListeners();
  }

  /// The clock runs only after the first move, in the foreground, unpaused
  /// and unwon.
  void _syncClock() {
    final shouldRun = _moved && _foreground && !_paused && !_game.isWon;
    if (shouldRun) {
      clock.start(_game.elapsed);
    } else {
      clock.stop();
    }
  }

  void _onClockTick(Duration delta) {
    if (_game.isWon) return;
    _game = _game.tick(delta);
    displayGame.value = _game;
  }

  /// Adds the clock's unflushed part to the game so a move's score uses
  /// exact time.
  void _flushClock() {
    final delta = clock.flush();
    if (delta > Duration.zero) _game = _game.tick(delta);
  }

  /// Records a new game state from a move: the display copy, the first-move
  /// gate and the clock.
  void _commit(Game game) {
    final before = _game;
    _game = game;
    displayGame.value = game;
    _emit(deriveFeedback(before, game));
    if (!_moved) _moved = true;
    _hasMove = true;
    _syncClock();
    gameChanged.fire();
    if (game.isWon) {
      events.value = Won(game);
      _winTimer?.cancel();
      _winTimer = Timer(winCardDelay, _showWin);
    } else if (settings.autoFinish &&
        game is KlondikeGame &&
        _sweep == null &&
        engine.isSolved(game)) {
      _startSweep(game);
    }
  }

  final ValueNotifier<PlaySettings> playSettings;
  final ValueNotifier<DisplayOptions> displayOptions;

  /// Where NEW and Switch get their numbers; tests inject a fixed one.
  final DealNumber Function() dealNumberSource;

  Game _game;
  Game get game => _game;

  /// The selected run: its pile and the index of its first card.
  (BoardPile, int)? _selection;
  (BoardPile, int)? get selection => _selection;

  UiHint? _hint;
  UiHint? get currentHint => _hint;

  ShakeTarget? _shake;
  ShakeTarget? get shake => _shake;
  int _shakeSequence = 0;
  Timer? _shakeTimer;

  /// The last tap, for double-tap detection: pile, index, when, and the card
  /// it touched (followed to wherever it now is).
  (BoardPile, int?, Duration, Card?)? _lastTap;

  /// The timestamp of the tap being handled, and of the last Spider deal.
  Duration _tapAt = Duration.zero;
  Duration? _lastDealAt;

  DragState? _dragging;
  DragState? get dragging => _dragging;

  /// Whether the board animates (#99); the board sets it each build. Under
  /// [AppMotion.none] the finish sweep completes at once and a refused drop
  /// springs home instantly.
  AppMotion motion = AppMotion.full;

  int _installSequence = 0;
  int _newGameSequence = 0;
  int _pendingDeal = 0;

  /// A one-shot token the board consumes to deal the new game with the
  /// animation (#103): raised by `replaceGame(…, dealAnimation: true)` and
  /// `restart()`, never by a resume. The board compares it with the value
  /// it last consumed.
  int get pendingDeal => _pendingDeal;

  /// Bumped on a new game only (new deal, restart, a setup Deal, a found
  /// deal) — not on resume — so the music restarts from the top (#101).
  int get newGameSequence => _newGameSequence;

  /// One step per action: what it did, for sounds (#101) and ticks (#107).
  /// Notifies on every assignment, even of an equal step.
  final feedback = _StepNotifier();

  void _emit(Set<FeedbackEvent> events, {bool sweep = false}) {
    if (events.isEmpty) return;
    feedback.value = FeedbackStep(events, sweep: sweep);
  }

  /// Bumped whenever a different game is installed (new deal, restart,
  /// resume), so the board snaps instead of animating between two deals.
  int get installSequence => _installSequence;

  SpringBack? _springBack;
  SpringBack? get springBack => _springBack;
  int _springSequence = 0;
  Timer? _springTimer;

  int? _peekColumn;
  int? get peekColumn => _peekColumn;

  PlaySettings get settings => playSettings.value;
  DisplayOptions get display => displayOptions.value;

  /// Swaps the game without touching the clock: an undo back to the deal
  /// leaves time running (owner, /n8-plan M3 round one). Clears the
  /// selection, hint and gestures; notifies.
  void replaceGameKeepingClock(Game game) {
    _game = game;
    displayGame.value = game;
    _selection = null;
    _hint = null;
    _lastTap = null;
    _clearShake();
    _dragging = null;
    _clearSpring();
    _peekColumn = null;
    _syncClock();
    gameChanged.fire();
    notifyListeners();
  }

  /// A new game: the old one, if it had a move, is not yet won and is of the
  /// same type, is abandoned (a loss, #85). Clears everything transient and
  /// notifies; the clock waits for a first move.
  void replaceGame(Game game, {bool dealAnimation = false}) {
    _abandonIf(GameType.of(game) == GameType.of(_game), AbandonReason.newDeal);
    _newGameSequence++;
    _install(game, hasMove: false);
    if (dealAnimation) _pendingDeal++;
    _emit({FeedbackEvent.newDeal});
  }

  /// The same game again after a restart or the app closing: nothing is
  /// recorded; [hasMove] says whether it already counts as played.
  void resumeGame(Game game, {required bool hasMove}) =>
      _install(game, hasMove: hasMove);

  void _abandonIf(bool sameType, AbandonReason reason) {
    if (_hasMove && sameType && !_game.isWon) {
      events.value = Abandoned(_game, reason);
    }
  }

  void _install(Game game, {required bool hasMove}) {
    _installSequence++;
    _sweep?.dispose();
    _sweep = null;
    _shownStep = null;
    _winTimer?.cancel();
    _winTimer = null;
    _winShown = false;
    _paused = false;
    _pauseOnReturn = false;
    _game = game;
    displayGame.value = game;
    _moved = false;
    _hasMove = hasMove;
    clock.reset();
    _selection = null;
    _hint = null;
    _lastTap = null;
    _lastDealAt = null;
    _clearShake();
    _dragging = null;
    _clearSpring();
    _peekColumn = null;
    gameChanged.fire();
    notifyListeners();
  }

  // ------------------------------------------------------------ tool row

  /// Undo is allowed by the engine under the Unlimited-undo setting.
  bool get canUndo => _game.canUndo(unlimited: settings.unlimitedUndo);

  /// Steps back one move (or one finish sweep), instantly; the clock keeps
  /// running. Clears the selection, the hint and any drag.
  void undo() {
    if (!canUndo || _sweep != null) return;
    final result = _game.undo(unlimited: settings.unlimitedUndo);
    if (result is Applied<Game>) {
      replaceGameKeepingClock(result.game);
      _emit({FeedbackEvent.snap}); // an undo snaps, never flips or chimes
    }
  }

  /// FINISH is offered only when the sweep really completes (#67).
  bool get canFinish => switch (_game) {
    KlondikeGame k => !k.isWon && engine.canFinish(k),
    SpiderGame() => false,
  };

  /// Sweeps the board to the foundations as one undo step. (#80 steps the
  /// animation; here the sweep lands at once.)
  void finish() {
    final g = _game;
    if (g is! KlondikeGame || !canFinish || _sweep != null) return;
    _startSweep(g);
  }

  /// Spider's DEAL: the same refusal as tapping the stock.
  void dealRow() {
    if (_game is! SpiderGame || _game.isWon || _sweep != null) return;
    _hint = null;
    _dragging = null;
    _peekColumn = null;
    _apply(const DealRow(), shake: (const StockPile(), null));
    _selection = null;
    notifyListeners();
  }

  /// Rows left to deal (Spider), 0 otherwise.
  int get dealsLeft => switch (_game) {
    SpiderGame s => s.rowsLeft,
    KlondikeGame() => 0,
  };

  /// The same deal again, at once, waiting for a first move; a game with a
  /// move is abandoned first (#85).
  void restart() {
    _abandonIf(true, AbandonReason.restart);
    _newGameSequence++;
    _install(_game.restart(), hasMove: false);
    _pendingDeal++;
    _emit({FeedbackEvent.newDeal});
  }

  /// Adds the clock's unflushed part to the game (before a save or a stats
  /// record) and updates the display copy; no listeners fire.
  void flushClockIntoGame() {
    _flushClock();
    displayGame.value = _game;
  }

  /// A new random deal with the same options; the number is rerolled if it
  /// matches the current one.
  void newDeal() {
    var number = dealNumberSource();
    if (number == _game.dealNumber) number = dealNumberSource();
    replaceGame(dealAnimation: true, switch (_game) {
      KlondikeGame k => KlondikeGame.deal(number, k.options),
      SpiderGame s => SpiderGame.deal(number, s.options),
    });
  }

  /// HINT: shows the most useful move as amber rings, or the "No moves
  /// left" notice; pressing it while a hint shows hides it. Clears the
  /// selection.
  void hint() {
    if (_game.isWon || _sweep != null) return;
    _selection = null;
    if (_hint != null) {
      _hint = null;
      notifyListeners();
      return;
    }
    _hint = _translate(engine.hint(_game));
    notifyListeners();
  }

  /// Hides a showing hint or notice (the "next action").
  void clearHint() {
    if (_hint == null) return;
    _hint = null;
    notifyListeners();
  }

  /// The engine's hint on the board's piles: the hinted run and where it
  /// goes, the stock for a draw, recycle or deal, or no moves.
  UiHint _translate(engine.Hint h) {
    switch (h) {
      case engine.NoMovesLeft():
        return const UiHint.noMoves();
      case engine.MoveHint(:final move):
        final g = _game;
        switch (move) {
          case MoveRun(:final from, :final start, :final to):
            return UiHint.move(
              source: TableauPile(from),
              start: start,
              destination: TableauPile(to),
            );
          case MoveCards(:final from, :final start, :final to):
            return UiHint.move(
              source: TableauPile(from),
              start: start,
              destination: TableauPile(to),
            );
          case WasteToTableau(:final to):
            final k = g as KlondikeGame;
            return UiHint.move(
              source: const WastePile(),
              start: k.waste.length - 1,
              destination: TableauPile(to),
            );
          case WasteToFoundation():
            final k = g as KlondikeGame;
            return UiHint.move(
              source: const WastePile(),
              start: k.waste.length - 1,
              destination: FoundationPile(k.waste.last.suit),
            );
          case TableauToFoundation(:final from):
            final k = g as KlondikeGame;
            final column = k.tableau[from];
            return UiHint.move(
              source: TableauPile(from),
              start: column.length - 1,
              destination: FoundationPile(column.last.suit),
            );
          case Flip(:final column):
            final cards = _pileCards(TableauPile(column))!;
            return UiHint.move(
              source: TableauPile(column),
              start: cards.length - 1,
              destination: null,
            );
          case Draw() || Recycle() || DealRow():
            return const UiHint.stock();
          case FoundationToTableau() || MoveGroup():
            return const UiHint.noMoves(); // never hinted by the engine
        }
    }
  }

  // ------------------------------------------------------------ drag, peek

  /// Whether a drag may start from card [index] of [pile]: a Klondike valid
  /// run start, waste top or foundation top; a Spider same-suit run start.
  bool canDrag(BoardPile pile, int? index) {
    if (_game.isWon || _sweep != null || _paused) return false;
    final cards = _pileCards(pile);
    if (cards == null || cards.isEmpty) return false;
    switch (pile) {
      case WastePile():
      case FoundationPile():
        return index == null || index == cards.length - 1;
      case TableauPile(:final column):
        if (index == null || index >= cards.length || !cards[index].faceUp) {
          return false;
        }
        return switch (_game) {
          KlondikeGame k => KlondikeGame.isAlternatingRun(
            k.tableau[column],
            index,
          ),
          SpiderGame s => SpiderGame.isSameSuitRun(s.tableau[column], index),
        };
      case StockPile():
      case CompletedPile():
        return false;
    }
  }

  /// Lifts the run at [index] of [pile]; [homeRects] are its cards' rects
  /// and [grab] the finger position. Returns false when nothing draggable is
  /// there. Starting a drag clears the selection and hint.
  bool beginDrag(
    BoardPile pile,
    int? index,
    List<Rect> homeRects,
    Offset grab,
  ) {
    // A running spring-back no longer blocks input: it lands now (#99).
    _clearSpring();
    if (!canDrag(pile, index)) return false;
    final cards = _pileCards(pile)!;
    final start = pile is TableauPile ? index! : cards.length - 1;
    final run = cards.sublist(start);
    final rects = homeRects.sublist(start);
    final targets = <BoardPile>{};
    for (final m in _game.legalMoves()) {
      final t = _targetOf(pile, start, m);
      if (t != null) targets.add(t);
    }
    _selection = null;
    _hint = null;
    _peekColumn = null;
    _dragging = DragState(
      pile: pile,
      start: start,
      cards: run,
      homeRects: rects,
      grabOffset: grab - rects.first.topLeft,
      position: grab,
      targets: targets,
    );
    notifyListeners();
    return true;
  }

  /// The pile [m] moves the run at ([pile], [start]) to, or null when [m] is
  /// not that run's move. Klondike foundation moves name the own suit.
  BoardPile? _targetOf(BoardPile pile, int start, Move m) {
    final k = _game;
    switch (m) {
      case MoveRun(:final from, start: final s, :final to):
        return pile == TableauPile(from) && s == start ? TableauPile(to) : null;
      case WasteToTableau(:final to):
        return pile is WastePile ? TableauPile(to) : null;
      case WasteToFoundation():
        return pile is WastePile && k is KlondikeGame
            ? FoundationPile(k.waste.last.suit)
            : null;
      case TableauToFoundation(:final from):
        if (pile != TableauPile(from) || k is! KlondikeGame) return null;
        return start == k.tableau[from].length - 1
            ? FoundationPile(k.tableau[from].last.suit)
            : null;
      case FoundationToTableau(:final foundation, :final to):
        return pile == FoundationPile(Suit.values[foundation])
            ? TableauPile(to)
            : null;
      case MoveCards(:final from, start: final s, :final to):
        return pile == TableauPile(from) && s == start ? TableauPile(to) : null;
      default:
        return null;
    }
  }

  void updateDrag(Offset position) {
    final d = _dragging;
    if (d == null) return;
    _dragging = d.moved(position);
    notifyListeners();
  }

  /// Drops on [target] (the pile under the finger, or null for felt). A pile
  /// that accepts the run takes it through the engine — a Klondike drop on
  /// any foundation goes to the card's own suit; anything else, the source
  /// pile included, springs the run home without calling the engine.
  bool endDrag(BoardPile? target) {
    final d = _dragging;
    if (d == null) return false;
    _dragging = null;
    var to = target;
    if (to is FoundationPile && _game is KlondikeGame) {
      to = FoundationPile(d.cards.first.suit);
    }
    if (to != null && to != d.pile) {
      final m = _moveFor(d.pile, d.start, to);
      if (m != null) {
        _flushClock();
        final result = _game.apply(m);
        if (result is Applied<Game>) {
          _commit(result.game);
          _clearShake();
          onApplied(result);
          notifyListeners();
          return true;
        }
      }
    }
    _springHome(d);
    notifyListeners();
    return false;
  }

  /// Snaps a drag home at once (undo, pause, a second finger, a cancel).
  void cancelDrag() {
    if (_dragging == null && _peekColumn == null) return;
    _dragging = null;
    _peekColumn = null;
    notifyListeners();
  }

  void _springHome(DragState d) {
    _springTimer?.cancel();
    if (motion == AppMotion.none) {
      // Instant: the cards are already drawn at home.
      _springBack = null;
      return;
    }
    _springSequence++;
    _springBack = SpringBack(
      pile: d.pile,
      start: d.start,
      cards: d.cards,
      from: d.rects,
      to: d.homeRects,
      sequence: _springSequence,
    );
    _springTimer = Timer(springBackDuration, () {
      _springBack = null;
      _springTimer = null;
      notifyListeners();
    });
  }

  void _clearSpring() {
    _springTimer?.cancel();
    _springTimer = null;
    _springBack = null;
  }

  /// Whether column [column] has face-up cards to fan.
  bool canPeek(int column) {
    final cards = _pileCards(TableauPile(column));
    return cards != null &&
        cards.any((c) => c.faceUp) &&
        _dragging == null &&
        _sweep == null &&
        !_paused;
  }

  void startPeek(int column) {
    _emit({FeedbackEvent.peek});
    if (!canPeek(column)) return;
    _peekColumn = column;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void endPeek() {
    if (_peekColumn == null) return;
    _peekColumn = null;
    notifyListeners();
  }

  /// Shakes [pile] from [start] for [shakeDuration]; the target clears
  /// itself afterwards with a second notification.
  void startShake(BoardPile pile, int? start) {
    _emit({FeedbackEvent.refused});
    _shakeTimer?.cancel();
    _shakeSequence++;
    _shake = ShakeTarget(pile, start, _shakeSequence);
    _shakeTimer = Timer(shakeDuration, () {
      _shake = null;
      _shakeTimer = null;
      notifyListeners();
    });
  }

  void _clearShake() {
    _shakeTimer?.cancel();
    _shakeTimer = null;
    _shake = null;
  }

  // ------------------------------------------------------------------ taps

  /// A tap on [pile] at card [index] (null: the pile itself or its empty
  /// strip) at [at] (a pointer timestamp, for the double-tap window).
  void tapPile(BoardPile? pile, int? index, {Duration at = Duration.zero}) {
    if (_game.isWon || _sweep != null || _paused) return;
    _hint = null; // any tap clears a showing hint
    _tapAt = at;
    final last = _lastTap;
    final isDouble =
        last != null &&
        pile != null &&
        last.$1 == pile &&
        last.$2 == index &&
        at - last.$3 <= doubleTapWindow &&
        last.$4 != null &&
        pile is! StockPile;
    if (isDouble) {
      _lastTap = null;
      _doubleTap(last.$4!);
      notifyListeners();
      return;
    }
    final touched = pile == null ? null : _cardAt(pile, index);
    _lastTap = pile == null ? null : (pile, index, at, touched);
    if (pile == null) {
      _selection = null;
    } else if (_selection == null) {
      _tapWithoutSelection(pile, index);
    } else {
      _tapWithSelection(pile, index);
    }
    notifyListeners();
  }

  /// Taps on the felt clear the selection.
  void tapFelt({Duration at = Duration.zero}) => tapPile(null, null, at: at);

  Card? _cardAt(BoardPile pile, int? index) {
    final cards = _pileCards(pile);
    if (cards == null || cards.isEmpty) return null;
    if (pile is WastePile || pile is FoundationPile) return cards.last;
    if (index == null) return cards.last;
    return index < cards.length ? cards[index] : null;
  }

  List<Card>? _pileCards(BoardPile pile) {
    final g = _game;
    return switch ((g, pile)) {
      (KlondikeGame k, TableauPile p) => k.tableau[p.column],
      (KlondikeGame k, WastePile()) => k.waste,
      (KlondikeGame k, FoundationPile p) => k.foundations[p.suit.index],
      (KlondikeGame k, StockPile()) => k.stock,
      (SpiderGame s, TableauPile p) => s.tableau[p.column],
      _ => null,
    };
  }

  /// The second tap of a double-tap: the touched card, wherever it now is,
  /// goes to its foundation (Klondike) or its best column (Spider) if legal.
  void _doubleTap(Card touched) {
    final g = _game;
    switch (g) {
      case KlondikeGame k:
        if (k.waste.isNotEmpty && k.waste.last == touched.up) {
          _apply(const WasteToFoundation(), shake: null);
          _selection = null;
          return;
        }
        for (var c = 0; c < klondikeColumns; c++) {
          final column = k.tableau[c];
          if (column.isNotEmpty && column.last == touched.up) {
            if (k.acceptsOnFoundation(column.last)) {
              _apply(TableauToFoundation(c), shake: null);
              _selection = null;
            }
            return;
          }
        }
      case SpiderGame s:
        for (var c = 0; c < spiderColumns; c++) {
          final column = s.tableau[c];
          final i = column.indexOf(touched.up);
          if (i < 0) continue;
          // The whole same-suit run goes, whichever of its cards was tapped.
          final start = SpiderGame.runBase(column);
          final dest = engine.bestDestination(
            s,
            engine.PileRef.tableau(c, start),
          );
          if (dest != null) {
            _apply(dest, shake: null);
            _selection = null;
          }
          return;
        }
    }
  }

  /// Where a Spider tap at [index] selects: the longest same-suit run
  /// ending at the column's top that includes the tapped card, else the
  /// top's own run.
  int _spiderRunStart(SpiderGame s, int column, int index) {
    final base = SpiderGame.runBase(s.tableau[column]);
    return index >= base ? index : base;
  }

  void _tapWithoutSelection(BoardPile pile, int? index) {
    final g = _game;
    switch (pile) {
      case StockPile():
        _tapStock();
      case WastePile():
        if (g is! KlondikeGame || g.waste.isEmpty) return;
        _selectOrOneTap(pile, g.waste.length - 1, engine.PileRef.waste());
      case FoundationPile(:final suit):
        if (g is! KlondikeGame) return;
        final pileCards = g.foundations[suit.index];
        if (pileCards.isEmpty) return;
        // A foundation card is never one-tapped away (M2): select it.
        _selection = (pile, pileCards.length - 1);
      case TableauPile(:final column):
        final cards = _pileCards(pile)!;
        if (cards.isEmpty) return;
        var i = index ?? cards.length - 1;
        if (i >= cards.length) i = cards.length - 1;
        final card = cards[i];
        if (!card.faceUp) {
          if (i == cards.length - 1 && !_autoFlip) {
            _apply(Flip(column), shake: null);
          }
          return;
        }
        final start = switch (g) {
          KlondikeGame k =>
            KlondikeGame.isAlternatingRun(k.tableau[column], i) ? i : -1,
          SpiderGame s => _spiderRunStart(s, column, i),
        };
        if (start < 0) return; // the middle of a broken run
        _selectOrOneTap(pile, start, engine.PileRef.tableau(column, start));
      case CompletedPile():
        return; // acts as felt: nothing to select
    }
  }

  bool get _autoFlip => switch (_game) {
    KlondikeGame k => k.options.autoFlip,
    SpiderGame s => s.options.autoFlip,
  };

  void _selectOrOneTap(BoardPile pile, int start, engine.PileRef source) {
    if (settings.oneTap) {
      final dest = engine.bestDestination(_game, source);
      if (dest != null) {
        _apply(dest, shake: null);
        _selection = null;
        return;
      }
    }
    _selection = (pile, start);
  }

  void _tapStock() {
    final g = _game;
    switch (g) {
      case KlondikeGame k:
        if (k.stock.isNotEmpty) {
          _apply(const Draw(), shake: (const StockPile(), null));
        } else if (k.waste.isNotEmpty) {
          _apply(const Recycle(), shake: (const StockPile(), null));
        } else {
          startShake(const StockPile(), null);
        }
      case SpiderGame _:
        final lastDeal = _lastDealAt;
        if (lastDeal != null &&
            _tapAt - lastDeal < dealDebounce &&
            _tapAt >= lastDeal) {
          break; // too soon after the last deal: ignored, nothing shakes
        }
        final result = _apply(
          const DealRow(),
          shake: (const StockPile(), null),
        );
        if (result is Applied) _lastDealAt = _tapAt;
    }
    _selection = null;
  }

  void _tapWithSelection(BoardPile pile, int? index) {
    final (selPile, selStart) = _selection!;
    if (pile is StockPile) {
      _tapStock();
      return;
    }
    if (pile == selPile) {
      // Inside the source pile: re-tap the selection to clear it, tap another
      // selectable card to switch, anything else clears.
      final cards = _pileCards(pile) ?? const [];
      if (pile is TableauPile &&
          index != null &&
          index != selStart &&
          index < cards.length) {
        final card = cards[index];
        final start = switch (_game) {
          KlondikeGame k when card.faceUp =>
            KlondikeGame.isAlternatingRun(k.tableau[pile.column], index)
                ? index
                : -1,
          SpiderGame s when card.faceUp => _spiderRunStart(
            s,
            pile.column,
            index,
          ),
          _ => -1,
        };
        if (start >= 0 && start != selStart) {
          _selection = (pile, start);
          return;
        }
      }
      _selection = null;
      return;
    }
    final result = move(selPile, selStart, pile);
    if (result is Applied) {
      _selection = null;
      return;
    }
    // Refused: switch to the tapped card if it is selectable, else the
    // shake already ran; either way the old selection goes.
    _selection = null;
    final cards = _pileCards(pile);
    if (cards != null && cards.isNotEmpty) {
      final i = pile is TableauPile
          ? (index ?? cards.length - 1)
          : cards.length - 1;
      if (i < cards.length && cards[i].faceUp) {
        final start = switch (_game) {
          KlondikeGame k when pile is TableauPile =>
            KlondikeGame.isAlternatingRun(k.tableau[pile.column], i) ? i : -1,
          SpiderGame s when pile is TableauPile => _spiderRunStart(
            s,
            pile.column,
            i,
          ),
          KlondikeGame() => i,
          _ => -1,
        };
        if (start >= 0) {
          _clearShake();
          _selection = (pile, start);
        }
      }
    }
  }

  /// Moves the run at [start] in [from] onto [to] through the engine; a
  /// refusal shakes the run and returns the reason.
  ApplyResult<Game> move(BoardPile from, int start, BoardPile to) {
    final m = _moveFor(from, start, to);
    if (m == null) {
      startShake(from, start);
      _haptic();
      notifyListeners();
      return const Refused(RefusalReason.invalidMove);
    }
    final result = _apply(m, shake: (from, start));
    notifyListeners();
    return result;
  }

  Move? _moveFor(BoardPile from, int start, BoardPile to) {
    switch (_game) {
      case KlondikeGame k:
        switch ((from, to)) {
          case (WastePile(), TableauPile t):
            return WasteToTableau(t.column);
          case (WastePile(), FoundationPile()):
            return const WasteToFoundation();
          case (TableauPile f, TableauPile t):
            return MoveRun(f.column, start, t.column);
          case (TableauPile f, FoundationPile()):
            if (start != k.tableau[f.column].length - 1) return null;
            return TableauToFoundation(f.column);
          case (FoundationPile f, TableauPile t):
            return FoundationToTableau(f.suit.index, t.column);
          default:
            return null;
        }
      case SpiderGame _:
        if (from is TableauPile && to is TableauPile) {
          return MoveCards(from.column, start, to.column);
        }
        return null;
    }
  }

  /// Applies [m]; on a refusal shakes [shake] (when given) and buzzes.
  ApplyResult<Game> _apply(Move m, {required (BoardPile, int?)? shake}) {
    _flushClock();
    final result = _game.apply(m);
    switch (result) {
      case Applied(:final game):
        _commit(game);
        _clearShake();
        onApplied(result);
      case Refused():
        if (shake != null) startShake(shake.$1, shake.$2);
        _haptic();
    }
    return result;
  }

  /// A hook for the stories that react to every applied move (the clock,
  /// auto-finish).
  @protected
  void onApplied(Applied<Game> result) {}

  void _haptic() {
    if (settings.haptics) HapticFeedback.lightImpact();
  }

  void _onSettings() => notifyListeners();

  @override
  void dispose() {
    feedback.dispose();
    playSettings.removeListener(_onSettings);
    _shakeTimer?.cancel();
    _springTimer?.cancel();
    _lifecycle?.dispose();
    _sweep?.dispose();
    _winTimer?.cancel();
    clock.dispose();
    displayGame.dispose();
    gameChanged.dispose();
    events.dispose();
    super.dispose();
  }
}

/// A `ValueListenable<Game>` that notifies on every assignment, equal or
/// not: two games that differ only in `elapsed` are equal, and the top bar
/// must still redraw the clock.
class GameNotifier extends ChangeNotifier implements ValueListenable<Game> {
  GameNotifier(this._value);

  Game _value;

  @override
  Game get value => _value;

  set value(Game game) {
    _value = game;
    notifyListeners();
  }
}

/// A notifier that fires on every assignment: two equal steps in a row
/// are two actions.
class _StepNotifier extends ChangeNotifier
    implements ValueListenable<FeedbackStep?> {
  FeedbackStep? _value;

  @override
  FeedbackStep? get value => _value;

  set value(FeedbackStep? step) {
    _value = step;
    if (step != null) notifyListeners();
  }
}

/// What a committed change from [before] to [after] did, from the states
/// alone: a Spider row dealt, tableau cards turned up, runs and foundations
/// completed, a win — and otherwise a snap.
Set<FeedbackEvent> deriveFeedback(Game before, Game after) {
  final events = <FeedbackEvent>{};
  switch ((before, after)) {
    case (SpiderGame b, SpiderGame a):
      if (a.stock.length < b.stock.length) events.add(FeedbackEvent.dealRow);
      if (a.completed.length > b.completed.length) {
        events.add(FeedbackEvent.runCompleted);
      }
      if (_tableauTurnedUp(b.tableau, a.tableau)) {
        events.add(FeedbackEvent.flip);
      }
    case (KlondikeGame b, KlondikeGame a):
      for (var i = 0; i < 4; i++) {
        if (a.foundations[i].length == kingRank &&
            b.foundations[i].length < kingRank) {
          events.add(FeedbackEvent.foundationCompleted);
        }
      }
      if (_tableauTurnedUp(b.tableau, a.tableau)) {
        events.add(FeedbackEvent.flip);
      }
    default:
      break;
  }
  if (after.isWon && !before.isWon) events.add(FeedbackEvent.win);
  if (events.isEmpty ||
      events.every(
        (e) =>
            e == FeedbackEvent.flip || e == FeedbackEvent.foundationCompleted,
      )) {
    events.add(FeedbackEvent.snap);
  }
  return events;
}

/// A face-down tableau card of [before] is face up in [after], by id.
bool _tableauTurnedUp(List<List<Card>> before, List<List<Card>> after) {
  final down = <int>{
    for (final column in before)
      for (final c in column)
        if (!c.faceUp && c.id >= 0) c.id,
  };
  if (down.isEmpty) return false;
  for (final column in after) {
    for (final c in column) {
      if (c.faceUp && down.contains(c.id)) return true;
    }
  }
  return false;
}
