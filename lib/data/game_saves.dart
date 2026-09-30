/// Saved games (#84): one slot per game type in the store, holding the
/// engine's JSON, the statistics flags (#85) and when it was saved; the menu's
/// Continue resumes whichever was played last.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:honest_solitaire/engine/game.dart';

import '../ui/game/game_controller.dart';
import '../ui/game/game_event.dart';
import 'app_store.dart';

class SavedGame {
  const SavedGame({
    required this.game,
    required this.start,
    required this.outcome,
    required this.savedAt,
  });

  final Game game;

  /// The game has had a move: it counts as played once its outcome is known.
  final bool start;

  /// Its outcome (win or loss) has been recorded in the statistics.
  final bool outcome;

  /// Epoch milliseconds of the save.
  final int savedAt;

  GameType get type => GameType.of(game);

  /// Offered by Continue: a game with a move and no outcome yet.
  bool get resumable => start && !outcome && !game.isWon;
}

class SavedGames {
  const SavedGames({this.klondike, this.spider, this.lastPlayed});

  final SavedGame? klondike;
  final SavedGame? spider;
  final GameType? lastPlayed;

  SavedGame? operator [](GameType type) => switch (type) {
    GameType.klondike => klondike,
    GameType.spider => spider,
  };

  SavedGames copyWith({
    SavedGame? klondike,
    bool clearKlondike = false,
    SavedGame? spider,
    bool clearSpider = false,
    GameType? lastPlayed,
  }) => SavedGames(
    klondike: clearKlondike ? null : (klondike ?? this.klondike),
    spider: clearSpider ? null : (spider ?? this.spider),
    lastPlayed: lastPlayed ?? this.lastPlayed,
  );

  /// The game Continue offers: the last played if it is resumable, else the
  /// other type's, else null.
  SavedGame? get resumeTarget {
    final last = lastPlayed;
    if (last != null && (this[last]?.resumable ?? false)) return this[last];
    for (final type in GameType.values) {
      final slot = this[type];
      if (slot != null && slot.resumable) return slot;
    }
    return null;
  }
}

class GameSaves extends ChangeNotifier implements ValueListenable<SavedGames> {
  GameSaves(this.store, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppStore store;
  final int Function() _now;
  SavedGames _value = const SavedGames();

  @override
  SavedGames get value => _value;

  void _set(SavedGames v) {
    _value = v;
    notifyListeners();
  }

  /// Loads both slots and `meta`. A slot that will not parse, holds the
  /// wrong type or has already been recorded is quarantined or deleted.
  Future<void> load() async {
    final klondike = await _loadSlot(GameType.klondike);
    final spider = await _loadSlot(GameType.spider);
    GameType? last;
    final meta = await store.read(StoreDoc.meta);
    if (meta is Loaded) {
      final name = meta.data['lastPlayed'];
      if (name is String) {
        last = GameType.values.where((t) => t.name == name).firstOrNull;
      }
    }
    if (last == null) {
      final k = klondike?.savedAt ?? -1;
      final s = spider?.savedAt ?? -1;
      if (k >= 0 || s >= 0) last = k >= s ? GameType.klondike : GameType.spider;
    }
    _set(SavedGames(klondike: klondike, spider: spider, lastPlayed: last));
  }

  Future<SavedGame?> _loadSlot(GameType type) async {
    final result = await store.read(type.doc);
    if (result is! Loaded) return null;
    final data = result.data;
    final json = data['game'];
    if (json is! Map) {
      await store.quarantine(type.doc, 'no game object');
      return null;
    }
    final Game game;
    try {
      game = Game.fromJson(json.cast<String, Object?>());
    } on Object catch (e) {
      await store.quarantine(type.doc, 'the saved game does not load: $e');
      return null;
    }
    if (GameType.of(game) != type) {
      await store.quarantine(
        type.doc,
        'a ${GameType.of(game).name} game in the ${type.name} slot',
      );
      return null;
    }
    final recorded = data['recorded'];
    var start = game.moves > 0;
    var outcome = false;
    if (recorded is Map) {
      if (recorded['start'] is bool) start = recorded['start'] as bool;
      if (recorded['outcome'] is bool) outcome = recorded['outcome'] as bool;
    }
    final savedAt = data['savedAt'] is int ? data['savedAt'] as int : 0;
    final slot = SavedGame(
      game: game,
      start: start,
      outcome: outcome,
      savedAt: savedAt,
    );
    // A finished game, or one already counted, is not resumable: it goes.
    // (A won game not yet recorded is kept for #85 to count, then deleted.)
    if (slot.outcome && !game.isWon) {
      await store.delete(type.doc);
      return null;
    }
    return slot;
  }

  /// Saves [game] into its type's slot with its flags and makes its type
  /// the last played. Completes when the write lands.
  Future<void> save(
    Game game, {
    required bool start,
    bool outcome = false,
  }) async {
    final type = GameType.of(game);
    final slot = SavedGame(
      game: game,
      start: start,
      outcome: outcome,
      savedAt: _now(),
    );
    final lastChanged = _value.lastPlayed != type;
    _set(_slotUpdated(type, slot).copyWith(lastPlayed: type));
    await store.write(type.doc, _slotJson(slot));
    if (lastChanged) {
      await store.write(StoreDoc.meta, {'lastPlayed': type.name});
    }
  }

  Map<String, Object?> _slotJson(SavedGame slot) => {
    'game': slot.game.toJson(),
    'recorded': {'start': slot.start, 'outcome': slot.outcome},
    'savedAt': slot.savedAt,
  };

  SavedGames _slotUpdated(GameType type, SavedGame? slot) => switch (type) {
    GameType.klondike => _value.copyWith(
      klondike: slot,
      clearKlondike: slot == null,
    ),
    GameType.spider => _value.copyWith(spider: slot, clearSpider: slot == null),
  };

  /// Removes the slot (a win, or a recorded game).
  Future<void> clear(GameType type) async {
    _set(_slotUpdated(type, null));
    await store.delete(type.doc);
  }

  /// Updates the statistics flags on the slot, rewriting it.
  Future<void> markRecorded(GameType type, {bool? start, bool? outcome}) async {
    final slot = _value[type];
    if (slot == null) return;
    final updated = SavedGame(
      game: slot.game,
      start: start ?? slot.start,
      outcome: outcome ?? slot.outcome,
      savedAt: slot.savedAt,
    );
    _set(_slotUpdated(type, updated));
    await store.write(type.doc, _slotJson(updated));
  }

  Future<void> setLastPlayed(GameType type) async {
    if (_value.lastPlayed == type) return;
    _set(_value.copyWith(lastPlayed: type));
    await store.write(StoreDoc.meta, {'lastPlayed': type.name});
  }
}

/// How often the game in progress is written: the first change at once, then
/// at most one write per window with a trailing write of the latest game.
const Duration saveThrottle = Duration(milliseconds: 500);

/// How often the clock of a game in play is written without a move, so a
/// kill that Android gives no warning of loses at most this much (#172).
const Duration clockSaveInterval = Duration(seconds: 10);

/// Saves the controller's game as it changes (#84).
class GamePersistence {
  GamePersistence(this.controller, this.saves, {bool observeLifecycle = true}) {
    controller.gameChanged.addListener(_onChange);
    controller.events.addListener(_onEvent);
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    }
    _lastGame = controller.game;
    _clockSaves = Timer.periodic(clockSaveInterval, (_) => flush());
  }

  final GameController controller;
  final GameSaves saves;
  AppLifecycleListener? _lifecycle;
  late final Timer _clockSaves;

  Game? _lastGame;
  final Map<GameType, Timer> _windows = {};
  final Map<GameType, bool> _dirty = {};

  /// Each slot's elapsed as last written. Clock ticks change the game
  /// without a move, so they never mark a slot dirty; backgrounding compares
  /// against this instead.
  final Map<GameType, Duration> _writtenElapsed = {};
  bool _disposed = false;

  /// Writes that landed since construction, for tests.
  int writes = 0;

  void _onChange() {
    final game = controller.game;
    final type = GameType.of(game);
    final previous = _lastGame;
    _lastGame = game;
    if (previous != null &&
        GameType.of(previous) != type &&
        (_dirty[GameType.of(previous)] ?? false)) {
      // The type changed: the old slot's pending save goes out now.
      _write(previous, GameType.of(previous));
    }
    if (game.isWon) return; // the Won event clears the slot
    if (_windows.containsKey(type)) {
      _dirty[type] = true;
      return;
    }
    _write(game, type);
    _windows[type] = Timer(saveThrottle, () => _windowEnded(type));
  }

  void _windowEnded(GameType type) {
    _windows.remove(type);
    if (_dirty[type] ?? false) {
      _dirty[type] = false;
      final game = controller.game;
      if (GameType.of(game) == type && !game.isWon) {
        _write(game, type);
        _windows[type] = Timer(saveThrottle, () => _windowEnded(type));
      }
    }
  }

  void _write(Game game, GameType type) {
    _dirty[type] = false;
    _writtenElapsed[type] = game.elapsed;
    writes++;
    saves.save(game, start: controller.hasMove || game.moves > 0).ignore();
  }

  void _onEvent() {
    final event = controller.events.value;
    if (event is Won) {
      final type = GameType.of(event.game);
      _windows.remove(type)?.cancel();
      _dirty[type] = false;
      _writtenElapsed.remove(type);
      saves.clear(type).ignore();
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    // Inactive too: the clock stops there, and a kill can follow it with
    // no hidden or paused in between (#172).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      flush();
    }
  }

  /// Writes the latest game now if anything is pending, with the clock's
  /// part-second flushed into it first. A won game is not saved.
  void flush() {
    if (_disposed) return;
    final type = GameType.of(controller.game);
    if (controller.game.isWon) return;
    final pending = _dirty[type] ?? false;
    final written = _writtenElapsed[type];
    if (!pending && !_windows.containsKey(type) && written == null) return;
    controller.flushClockIntoGame();
    _windows.remove(type)?.cancel();
    final game = controller.game;
    // Time played since the last write is lost if Android kills the app
    // while it is in the background.
    final timePlayed =
        written != null &&
        game.elapsed != written &&
        (controller.hasMove || game.moves > 0);
    if (pending || timePlayed) _write(game, type);
  }

  void dispose() {
    flush();
    _disposed = true;
    _clockSaves.cancel();
    for (final t in _windows.values) {
      t.cancel();
    }
    _windows.clear();
    controller.gameChanged.removeListener(_onChange);
    controller.events.removeListener(_onEvent);
    _lifecycle?.dispose();
  }
}
