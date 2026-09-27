/// The board's state: the current game, the settings, the selection, the
/// active hint and the shake target (#74). Taps, gestures and the tool
/// actions are added by the stories that own them.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

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

  PlaySettings get settings => playSettings.value;
  DisplayOptions get display => displayOptions.value;

  /// Swaps the game, clearing the selection and hint; always notifies.
  void replaceGame(Game game) {
    _game = game;
    _selection = null;
    _hint = null;
    _clearShake();
    notifyListeners();
  }

  /// Replaces the game without touching the selection, hint or shake, and
  /// notifies.
  @protected
  void setGame(Game game) {
    _game = game;
    notifyListeners();
  }

  @protected
  void setSelection((BoardPile, int)? selection) {
    _selection = selection;
  }

  @protected
  void setHint(UiHint? hint) {
    _hint = hint;
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

  void _onSettings() => notifyListeners();

  @override
  void dispose() {
    playSettings.removeListener(_onSettings);
    _shakeTimer?.cancel();
    super.dispose();
  }
}
