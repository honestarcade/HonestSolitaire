/// The music loop's gate (#101): it plays only while a board is showing,
/// the game is unpaused, the app is in the foreground and the setting is
/// on; it pauses (keeping its place) when any of those stops being true,
/// and restarts from the beginning only on a new game. It never plays over
/// another app's audio: the bridge refuses, and a refused start is retried
/// at the next change.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../ui/game/game_controller.dart';
import '../ui/settings/play_settings.dart';
import 'sound_player.dart';

class MusicController {
  MusicController(
    this.controller,
    this.playSettings,
    this.boardVisible,
    this.player, {
    bool observeLifecycle = true,
  }) {
    controller.addListener(_reconcile);
    playSettings.addListener(_reconcile);
    boardVisible.addListener(_reconcile);
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    }
    _newGame = controller.newGameSequence;
  }

  final GameController controller;
  final ValueListenable<PlaySettings> playSettings;
  final ValueListenable<bool> boardVisible;
  final SoundPlayer player;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _playing = false;
  bool _starting = false;
  int _newGame = 0;
  Future<void> _chain = Future.value();

  /// Whether the gate is open right now, for tests.
  bool get playing => _playing;

  /// The bridge calls in order, for tests.
  final List<String> calls = [];

  void _onLifecycle(AppLifecycleState state) {
    final before = _foreground;
    _foreground = switch (state) {
      AppLifecycleState.paused || AppLifecycleState.hidden => false,
      AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.detached => false,
    };
    if (before != _foreground) _reconcile();
  }

  /// Serialised, so a pause never overtakes the start before it.
  void _later(Future<void> Function() action) {
    _chain = _chain.then((_) => action()).catchError((Object _) {});
  }

  void _reconcile() {
    if (controller.newGameSequence != _newGame) {
      _newGame = controller.newGameSequence;
      _playing = false;
      calls.add('stop');
      _later(player.stopMusic);
    }
    final wants =
        playSettings.value.music &&
        boardVisible.value &&
        !controller.isPaused &&
        _foreground;
    if (wants && !_playing && !_starting) {
      _starting = true;
      _later(() async {
        calls.add('start');
        _playing = await player.startMusic();
        _starting = false;
      });
    } else if (!wants && _playing) {
      _playing = false;
      calls.add('pause');
      _later(player.pauseMusic);
    }
  }

  /// Everything queued has run, for tests.
  Future<void> settle() => _chain;

  void dispose() {
    controller.removeListener(_reconcile);
    playSettings.removeListener(_reconcile);
    boardVisible.removeListener(_reconcile);
    _lifecycle?.dispose();
    if (_playing) unawaited(player.pauseMusic());
  }
}
