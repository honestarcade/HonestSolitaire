/// Spoken announcements for TalkBack (#108): one door for every
/// `SemanticsService.sendAnnouncement` in the app (the announcer scan keeps
/// it that way), speaking only while a screen reader is on, and injectable
/// so tests read what would have been said.
library;

import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../game/game_controller.dart';

abstract class Announcer {
  /// Speaks [text] to the screen reader, if one is on.
  void announce(BuildContext context, String text);
}

/// Speaks through the platform, only under `accessibleNavigation` (a
/// screen reader): nobody else hears an announcement, and an unmounted
/// context says nothing.
class FlutterAnnouncer implements Announcer {
  const FlutterAnnouncer();

  @override
  void announce(BuildContext context, String text) {
    if (!context.mounted) return;
    if (!MediaQuery.accessibleNavigationOf(context)) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        TextDirection.ltr,
      ),
    );
  }
}

/// Records what would have been said, for tests.
class RecordingAnnouncer implements Announcer {
  final List<String> spoken = [];

  @override
  void announce(BuildContext context, String text) => spoken.add(text);
}

/// Speaks the controller's spoken steps (a move, a refusal, a hint, a
/// selection, an undo — `GameController.spoken`) through [announcer].
class BoardAnnouncements {
  BoardAnnouncements(this.controller, this.announcer, this.context) {
    controller.spoken.addListener(_onSpoken);
  }

  final GameController controller;
  final Announcer announcer;

  /// The context to speak from (the app root's).
  final BuildContext Function() context;

  void _onSpoken() {
    final text = controller.spoken.value;
    if (text == null) return;
    announcer.announce(context(), text);
  }

  void dispose() => controller.spoken.removeListener(_onSpoken);
}
