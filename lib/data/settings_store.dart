/// The `settings` document (#86): every Play, Display and Sound toggle, the
/// card back, and the last-used options of each setup screen (#88, #89),
/// always written whole, loaded with per-field fallbacks.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../ui/card/card_style.dart';
import '../ui/settings/display_options.dart';
import '../ui/settings/play_settings.dart';
import 'app_store.dart';

/// The first-run defaults of the setup screens.
const KlondikeOptions firstRunKlondike = KlondikeOptions(draw: DrawMode.three);
const SpiderOptions firstRunSpider = SpiderOptions(suits: SpiderSuits.two);

/// How often a settings change is written: at once, then one per window.
const Duration settingsThrottle = Duration(milliseconds: 500);

class SettingsStore {
  SettingsStore(
    this.store,
    this.play,
    this.display, {
    bool observeLifecycle = true,
  }) {
    play.addListener(_changed);
    display.addListener(_changed);
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    }
  }

  final AppStore store;
  final ValueNotifier<PlaySettings> play;
  final ValueNotifier<DisplayOptions> display;
  AppLifecycleListener? _lifecycle;

  KlondikeOptions _lastKlondike = firstRunKlondike;
  SpiderOptions _lastSpider = firstRunSpider;

  /// The options the New Klondike / New Spider screens preselect.
  KlondikeOptions get lastKlondikeOptions => _lastKlondike;
  SpiderOptions get lastSpiderOptions => _lastSpider;

  bool _loaded = false;
  bool _applying = false;
  Timer? _window;
  bool _dirty = false;
  Map<String, Object?>? _lastWritten;

  /// Writes that landed, for tests.
  int writes = 0;

  /// Reads the document into the notifiers; missing or bad fields keep
  /// their defaults. Nothing is written until the first change.
  Future<void> load() async {
    final result = await store.read(StoreDoc.settings);
    if (result is Loaded) {
      final d = result.data;
      bool b(String key, bool fallback) =>
          d[key] is bool ? d[key] as bool : fallback;
      final p = play.value;
      final v = display.value;
      final back =
          CardBack.values.where((c) => c.name == d['cardBack']).firstOrNull ??
          v.cardBack;
      _applying = true;
      play.value = PlaySettings(
        oneTap: b('oneTap', p.oneTap),
        autoFinish: b('autoFinish', p.autoFinish),
        autoFlip: b('autoFlip', p.autoFlip),
        unlimitedUndo: b('unlimitedUndo', p.unlimitedUndo),
        winnableOnly: b('winnableOnly', p.winnableOnly),
        cardAnimations: b('cardAnimations', p.cardAnimations),
        sound: b('sound', p.sound),
        music: b('music', p.music),
        haptics: b('haptics', p.haptics),
      );
      display.value = DisplayOptions(
        leftHanded: b('leftHanded', v.leftHanded),
        largeCards: b('largeCards', v.largeCards),
        cardBack: back,
        showTimer: b('showTimer', v.showTimer),
        showMovesAndScore: b('showMovesAndScore', v.showMovesAndScore),
      );
      _applying = false;
      final k = d['lastKlondikeOptions'];
      if (k is Map) _lastKlondike = _klondikeFrom(k.cast<String, Object?>());
      final s = d['lastSpiderOptions'];
      if (s is Map) _lastSpider = _spiderFrom(s.cast<String, Object?>());
      _lastWritten = _json();
    }
    _loaded = true;
  }

  KlondikeOptions _klondikeFrom(Map<String, Object?> m) {
    final draw =
        DrawMode.values.where((x) => x.name == m['draw']).firstOrNull ??
        firstRunKlondike.draw;
    final scoring = _scoringFrom(m['scoring']) ?? firstRunKlondike.scoring;
    final timed = m['timed'] is bool
        ? m['timed'] as bool
        : firstRunKlondike.timed;
    return KlondikeOptions(draw: draw, scoring: scoring, timed: timed);
  }

  static ScoringMode? _scoringFrom(Object? name) =>
      ScoringMode.values.where((x) => x.name == name).firstOrNull;

  SpiderOptions _spiderFrom(Map<String, Object?> m) {
    final suits =
        SpiderSuits.values.where((x) => x.name == m['suits']).firstOrNull ??
        firstRunSpider.suits;
    final timed = m['timed'] is bool
        ? m['timed'] as bool
        : firstRunSpider.timed;
    final relaxed = m['relaxed'] is bool
        ? m['relaxed'] as bool
        : firstRunSpider.relaxed;
    return SpiderOptions(suits: suits, timed: timed, relaxed: relaxed);
  }

  Map<String, Object?> _json() {
    final p = play.value;
    final v = display.value;
    return {
      'oneTap': p.oneTap,
      'autoFinish': p.autoFinish,
      'autoFlip': p.autoFlip,
      'unlimitedUndo': p.unlimitedUndo,
      'winnableOnly': p.winnableOnly,
      'cardAnimations': p.cardAnimations,
      'sound': p.sound,
      'music': p.music,
      'haptics': p.haptics,
      'leftHanded': v.leftHanded,
      'largeCards': v.largeCards,
      'cardBack': v.cardBack.name,
      'showTimer': v.showTimer,
      'showMovesAndScore': v.showMovesAndScore,
      'lastKlondikeOptions': {
        'draw': _lastKlondike.draw.name,
        'scoring': _lastKlondike.scoring.name,
        'timed': _lastKlondike.timed,
      },
      'lastSpiderOptions': {
        'suits': _lastSpider.suits.name,
        'timed': _lastSpider.timed,
        'relaxed': _lastSpider.relaxed,
      },
    };
  }

  Future<void> setLastKlondikeOptions(KlondikeOptions options) {
    _lastKlondike = options;
    return _changedNow();
  }

  Future<void> setLastSpiderOptions(SpiderOptions options) {
    _lastSpider = options;
    return _changedNow();
  }

  void _changed() {
    if (_applying) return;
    _changedNow().ignore();
  }

  /// The leading change writes at once; further changes inside the window
  /// coalesce into one trailing write of the latest values.
  Future<void> _changedNow() {
    if (_window != null) {
      _dirty = true;
      return Future.value();
    }
    final done = _write();
    _window = Timer(settingsThrottle, _windowEnded);
    return done;
  }

  void _windowEnded() {
    _window = null;
    if (_dirty) {
      _dirty = false;
      _write().ignore();
      _window = Timer(settingsThrottle, _windowEnded);
    }
  }

  Future<void> _write() {
    final json = _json();
    if (_lastWritten != null && mapEquals(_lastWritten, json)) {
      return Future.value();
    }
    _lastWritten = json;
    writes++;
    return store.write(StoreDoc.settings, json);
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      flush();
    }
  }

  /// Writes the latest values now if a change is pending.
  void flush() {
    if (!_dirty) return;
    _window?.cancel();
    _window = null;
    _dirty = false;
    _write().ignore();
  }

  bool get loaded => _loaded;

  void dispose() {
    flush();
    _window?.cancel();
    play.removeListener(_changed);
    display.removeListener(_changed);
    _lifecycle?.dispose();
  }
}
