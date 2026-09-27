/// What the player hears and feels when something happens (#101, #107):
/// the controller's [FeedbackStep]s reduced to at most one clip by priority,
/// played when the Sound effects setting is on, and to at most one tick,
/// given when the Haptics setting is on; and the samples that answer the
/// player turning either setting on.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../ui/game/game_controller.dart';
import '../ui/settings/play_settings.dart';
import 'clips.dart';
import 'feedback_event.dart';
import 'haptics.dart';
import 'sound_player.dart';

export 'feedback_event.dart';

/// The one clip a step plays, or null. Priority: chime > deal > flip >
/// snap. A King reached inside the finish sweep does not chime; the win
/// does. Refusals, peeks and resumes are silent.
Clip? clipFor(FeedbackStep step) {
  if (step.has(FeedbackEvent.win) ||
      step.has(FeedbackEvent.runCompleted) ||
      (step.has(FeedbackEvent.foundationCompleted) && !step.sweep)) {
    return Clip.chime;
  }
  if (step.has(FeedbackEvent.newDeal) || step.has(FeedbackEvent.dealRow)) {
    return Clip.deal;
  }
  if (step.has(FeedbackEvent.flip)) return Clip.flip;
  if (step.has(FeedbackEvent.snap)) return Clip.snap;
  return null;
}

/// Whether a step ticks (#107, owner): a refused move, a Spider run
/// completing, a Klondike foundation reaching its King, a peek starting —
/// never an ordinary move. One tick per step however many of these it
/// holds; a sweep step ticks only when it completes a foundation.
bool tickFor(FeedbackStep step) =>
    step.has(FeedbackEvent.refused) ||
    step.has(FeedbackEvent.runCompleted) ||
    step.has(FeedbackEvent.foundationCompleted) ||
    step.has(FeedbackEvent.peek);

/// Plays the controller's steps through [player] while Sound effects is on
/// and ticks them through [haptics] while Haptics is on.
class GameFeedback {
  GameFeedback(
    this.controller,
    this.playSettings,
    this.player, [
    this.haptics = const NoHaptics(),
  ]) {
    controller.feedback.addListener(_onStep);
  }

  final GameController controller;
  final ValueListenable<PlaySettings> playSettings;
  final SoundPlayer player;
  final HapticsPort haptics;

  /// The clips played, newest last, for tests.
  final List<Clip> played = [];

  /// How many ticks were given, for tests.
  int ticks = 0;

  void _onStep() {
    final step = controller.feedback.value;
    if (step == null) return;
    final settings = playSettings.value;
    if (settings.haptics && tickFor(step)) {
      ticks++;
      unawaited(haptics.tick());
    }
    if (!settings.sound) return;
    final clip = clipFor(step);
    if (clip == null) return;
    played.add(clip);
    player.play(clip);
  }

  void dispose() => controller.feedback.removeListener(_onStep);
}

/// The samples a settings change plays or ticks: one snap when the player
/// turns Sound effects on (#101), one tick when they turn Haptics on
/// (#107) — by comparing with the previous values, and never while the
/// settings store is restoring them at launch.
class SettingsSamples {
  SettingsSamples(
    this.playSettings,
    this.store, {
    required this.onSoundOn,
    required this.onHapticsOn,
  }) : _previous = playSettings.value {
    playSettings.addListener(_onChange);
  }

  final ValueListenable<PlaySettings> playSettings;
  final SettingsStore store;
  final VoidCallback onSoundOn;
  final VoidCallback onHapticsOn;
  PlaySettings _previous;

  void _onChange() {
    final now = playSettings.value;
    final was = _previous;
    _previous = now;
    if (!store.loaded) return; // the restore, not the player
    if (now.sound && !was.sound) onSoundOn();
    if (now.haptics && !was.haptics) onHapticsOn();
  }

  void dispose() => playSettings.removeListener(_onChange);
}
