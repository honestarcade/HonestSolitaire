/// A short tick on a refused move, a completed run or suit and the peek
/// (#107), through Flutter's own haptic call: no plugin and no permission.
/// On Android it goes through performHapticFeedback, which follows the
/// phone's touch-feedback setting. Nothing outside this file calls
/// HapticFeedback (the haptics scan guards that), so the Haptics setting is
/// checked in one place: game_feedback.dart.
library;

import 'dart:developer' as developer;

import 'package:flutter/services.dart';

abstract class HapticsPort {
  /// One light tick.
  Future<void> tick();
}

/// No ticks.
class NoHaptics implements HapticsPort {
  const NoHaptics();

  @override
  Future<void> tick() async {}
}

/// Ticks through [HapticFeedback.lightImpact]. A platform without haptics
/// logs one line, once, and stays quiet.
class FlutterHaptics implements HapticsPort {
  FlutterHaptics({void Function(String message)? log})
    : _log = log ?? _defaultLog;

  final void Function(String) _log;
  bool _logged = false;

  static void _defaultLog(String message) =>
      developer.log(message, name: 'honest_solitaire.haptics');

  @override
  Future<void> tick() async {
    try {
      await HapticFeedback.lightImpact();
    } on MissingPluginException catch (e) {
      _once('no haptics: $e');
    } on PlatformException catch (e) {
      _once('haptics failed: $e');
    }
  }

  void _once(String message) {
    if (_logged) return;
    _logged = true;
    _log(message);
  }
}
