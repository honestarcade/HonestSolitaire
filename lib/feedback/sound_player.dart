/// Plays the game's sounds through `SoundBridge.kt` (#101): SoundPool for
/// the effects, a looping MediaPlayer for the music, no plugin. Anywhere the
/// channel is missing (tests, a platform without the bridge) it logs once
/// and stays silent; a sound is never allowed to throw into the UI.
library;

import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'clips.dart';

/// The channel SoundBridge.kt listens on.
const String kSoundChannel = 'honestsolitaire/sound';

abstract class SoundPlayer {
  /// Loads every clip's asset. Plays before this completes are dropped.
  Future<void> load(Map<Clip, ClipSpec> clips);

  /// Plays [clip], if it loaded.
  void play(Clip clip);

  /// Starts the loop; false when it did not (another app's audio, no
  /// bridge, a dead player).
  Future<bool> startMusic();

  /// Holds the loop where it is.
  Future<void> pauseMusic();

  /// Holds the loop and resets it to the beginning.
  Future<void> stopMusic();

  /// Releases everything loaded.
  Future<void> dispose();
}

class NoSoundPlayer implements SoundPlayer {
  const NoSoundPlayer();

  @override
  Future<void> load(Map<Clip, ClipSpec> clips) async {}

  @override
  void play(Clip clip) {}

  @override
  Future<bool> startMusic() async => false;

  @override
  Future<void> pauseMusic() async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> dispose() async {}
}

class ChannelSoundPlayer implements SoundPlayer {
  ChannelSoundPlayer({
    this.channel = const MethodChannel(kSoundChannel),
    void Function(String message)? log,
  }) : _log = log ?? _defaultLog;

  final MethodChannel channel;
  final void Function(String) _log;
  bool _loaded = false;
  bool _dead = false;
  final Set<Clip> _playFailed = {};

  static void _defaultLog(String message) =>
      developer.log(message, name: 'honest_solitaire.sound');

  bool get loaded => _loaded;

  @override
  Future<void> load(Map<Clip, ClipSpec> clips) async {
    if (_dead) return;
    try {
      final loaded = await channel.invokeMethod<int>('load', {
        for (final e in clips.entries) e.key.name: e.value.asset,
      });
      _loaded = true;
      if (loaded != clips.length) {
        _log('sound: ${loaded ?? 0} of ${clips.length} clips loaded');
      }
    } on Object catch (e) {
      // A failed load disables sound for the session, once.
      _dead = true;
      _log('sound: no player, playing nothing ($e)');
    }
  }

  @override
  void play(Clip clip) {
    if (_dead || !_loaded) return;
    channel.invokeMethod<void>('play', clip.name).catchError((Object error) {
      if (_playFailed.add(clip)) {
        _log('sound: ${clip.name} did not play ($error)');
      }
    });
  }

  Future<T?> _music<T>(String method) async {
    if (_dead || !_loaded) return null;
    try {
      return await channel.invokeMethod<T>(method);
    } on Object catch (e) {
      _log('sound: $method failed ($e)');
      return null;
    }
  }

  @override
  Future<bool> startMusic() async => await _music<bool>('musicStart') ?? false;

  @override
  Future<void> pauseMusic() => _music<void>('musicPause');

  @override
  Future<void> stopMusic() => _music<void>('musicStop');

  @override
  Future<void> dispose() async {
    if (_dead || !_loaded) return;
    _loaded = false;
    try {
      await channel.invokeMethod<void>('release');
    } on Object catch (e) {
      _log('sound: release failed ($e)');
    }
  }
}
