/// The board's state and its tap rules: the current game, the settings,
/// the selection, the active hint, the shake target (#74) and every tap a
/// player can make (#75 Klondike, #76 Spider). Every move goes through the
/// engine's `apply`; the controller never changes a pile itself.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart' as engine;

import '../board/pile_ref.dart';
import '../settings/display_options.dart';
import '../settings/play_settings.dart';
import 'ui_hint.dart';

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

class GameController extends ChangeNotifier {
  GameController(
    Game game,
    this.playSettings,
    this.displayOptions, {
    DealNumber Function()? dealNumberSource,
  }) : _game = game,
       dealNumberSource = dealNumberSource ?? DealNumber.random {
    playSettings.addListener(_onSettings);
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

  PlaySettings get settings => playSettings.value;
  DisplayOptions get display => displayOptions.value;

  /// Swaps the game, clearing the selection and hint; always notifies.
  void replaceGame(Game game) {
    _game = game;
    _selection = null;
    _hint = null;
    _lastTap = null;
    _clearShake();
    notifyListeners();
  }

  /// Shakes [pile] from [start] for [shakeDuration]; the target clears
  /// itself afterwards with a second notification.
  void startShake(BoardPile pile, int? start) {
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
    if (_game.isWon) return;
    _hint = null; // any tap clears a showing hint
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
          final start = _spiderRunStart(s, c, i);
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
        _apply(const DealRow(), shake: (const StockPile(), null));
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
      return const Refused(RefusalReason.invalidMove);
    }
    return _apply(m, shake: (from, start));
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
    final result = _game.apply(m);
    switch (result) {
      case Applied(:final game):
        _game = game;
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
    playSettings.removeListener(_onSettings);
    _shakeTimer?.cancel();
    super.dispose();
  }
}
