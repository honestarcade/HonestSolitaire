/// Statistics (#85), recorded honestly from play and kept per game on the
/// device: played, won, the current streak, best time (timed wins), fewest
/// moves (any win), high score (standard Klondike and Spider), total play
/// time (every game), the breakdown by draw mode or suit count, and
/// Klondike's Vegas lifetime dollars.
///
/// The rules are pure functions over an immutable `StatsDocument`, so they
/// are testable without Flutter; `StatsRecorder` is the thin persistent
/// wrapper and `StatsListener` the hook on the controller's events.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../ui/game/game_controller.dart';
import '../ui/game/game_event.dart';
import 'app_store.dart';
import 'game_saves.dart';

/// A game's headline numbers. Counters start at 0; records are null until
/// set.
class TotalStats {
  const TotalStats({
    this.played = 0,
    this.won = 0,
    this.streak = 0,
    this.playMs = 0,
    this.bestTimeMs,
    this.fewestMoves,
    this.highScore,
  });

  final int played;
  final int won;
  final int streak;

  /// Every game's time, won or not, added when its outcome is recorded.
  final int playMs;
  final int? bestTimeMs;
  final int? fewestMoves;
  final int? highScore;

  TotalStats copyWith({
    int? played,
    int? won,
    int? streak,
    int? playMs,
    int? bestTimeMs,
    int? fewestMoves,
    int? highScore,
  }) => TotalStats(
    played: played ?? this.played,
    won: won ?? this.won,
    streak: streak ?? this.streak,
    playMs: playMs ?? this.playMs,
    bestTimeMs: bestTimeMs ?? this.bestTimeMs,
    fewestMoves: fewestMoves ?? this.fewestMoves,
    highScore: highScore ?? this.highScore,
  );

  Map<String, Object?> toJson() => {
    'played': played,
    'won': won,
    'streak': streak,
    'playMs': playMs,
    'bestTimeMs': bestTimeMs,
    'fewestMoves': fewestMoves,
    'highScore': highScore,
  };

  static TotalStats fromJson(Object? json) {
    if (json is! Map) return const TotalStats();
    final played = _counter(json['played']);
    final won = _counter(json['won']);
    return TotalStats(
      played: played,
      won: won > played ? played : won,
      streak: _counter(json['streak']),
      playMs: _counter(json['playMs']),
      bestTimeMs: _record(json['bestTimeMs']),
      fewestMoves: _record(json['fewestMoves']),
      highScore: _record(json['highScore'], allowNegative: false),
    );
  }
}

class ModeStats {
  const ModeStats({this.played = 0, this.won = 0});

  final int played;
  final int won;

  Map<String, Object?> toJson() => {'played': played, 'won': won};

  static ModeStats fromJson(Object? json) {
    if (json is! Map) return const ModeStats();
    final played = _counter(json['played']);
    final won = _counter(json['won']);
    return ModeStats(played: played, won: won > played ? played : won);
  }
}

/// Klondike's Vegas games: a lifetime dollar total, never a high score.
class VegasStats {
  const VegasStats({this.played = 0, this.won = 0, this.dollars = 0});

  final int played;
  final int won;
  final int dollars;

  Map<String, Object?> toJson() => {
    'played': played,
    'won': won,
    'dollars': dollars,
  };

  static VegasStats fromJson(Object? json) {
    if (json is! Map) return const VegasStats();
    final played = _counter(json['played']);
    final won = _counter(json['won']);
    final dollars = json['dollars'];
    return VegasStats(
      played: played,
      won: won > played ? played : won,
      dollars: dollars is int ? dollars : 0,
    );
  }
}

class GameStats {
  const GameStats({
    this.total = const TotalStats(),
    this.modes = const {},
    this.vegas,
  });

  final TotalStats total;

  /// Keyed by [modeKey]: `draw1`/`draw3` or `one`/`two`/`four`.
  final Map<String, ModeStats> modes;
  final VegasStats? vegas;

  ModeStats mode(String key) => modes[key] ?? const ModeStats();

  Map<String, Object?> toJson() => {
    'total': total.toJson(),
    'modes': {for (final e in modes.entries) e.key: e.value.toJson()},
    if (vegas != null) 'vegas': vegas!.toJson(),
  };

  static GameStats fromJson(Object? json, {required bool klondike}) {
    if (json is! Map) {
      return GameStats(vegas: klondike ? const VegasStats() : null);
    }
    final modesJson = json['modes'];
    final modes = <String, ModeStats>{};
    if (modesJson is Map) {
      for (final e in modesJson.entries) {
        if (e.key is String &&
            (klondike ? klondikeModeKeys : spiderModeKeys).contains(e.key)) {
          modes[e.key as String] = ModeStats.fromJson(e.value);
        }
      }
    }
    return GameStats(
      total: TotalStats.fromJson(json['total']),
      modes: modes,
      vegas: klondike ? VegasStats.fromJson(json['vegas']) : null,
    );
  }
}

const klondikeModeKeys = ['draw1', 'draw3'];
const spiderModeKeys = ['one', 'two', 'four'];

/// The fixed mode key for a game (not an enum name).
String modeKey(Game game) => switch (game) {
  KlondikeGame k => k.options.draw == DrawMode.one ? 'draw1' : 'draw3',
  SpiderGame s => switch (s.options.suits.count) {
    1 => 'one',
    2 => 'two',
    _ => 'four',
  },
};

int _counter(Object? v) => v is int && v >= 0 ? v : 0;

int? _record(Object? v, {bool allowNegative = false}) =>
    v is int && (allowNegative || v >= 0) ? v : null;

class StatsDocument {
  const StatsDocument({
    this.klondike = const GameStats(vegas: VegasStats()),
    this.spider = const GameStats(),
  });

  final GameStats klondike;
  final GameStats spider;

  static const empty = StatsDocument();

  GameStats operator [](GameType type) =>
      type == GameType.klondike ? klondike : spider;

  Map<String, Object?> toJson() => {
    'klondike': klondike.toJson(),
    'spider': spider.toJson(),
  };

  static StatsDocument fromJson(Map<String, Object?> json) => StatsDocument(
    klondike: GameStats.fromJson(json['klondike'], klondike: true),
    spider: GameStats.fromJson(json['spider'], klondike: false),
  );

  StatsDocument _with(GameType type, GameStats stats) =>
      type == GameType.klondike
      ? StatsDocument(klondike: stats, spider: spider)
      : StatsDocument(klondike: klondike, spider: stats);

  /// Whether a Klondike game's score counts towards the high score.
  static bool _scores(Game game) => switch (game) {
    KlondikeGame k => k.scoring == ScoringMode.standard,
    SpiderGame() => true,
  };

  static bool _timed(Game game) => switch (game) {
    KlondikeGame k => k.options.timed,
    SpiderGame s => s.options.timed,
  };

  /// A win: played and won up, the streak extended, the records moved only
  /// for the right reasons, the mode and (Vegas) dollars updated.
  StatsDocument recordWin(Game game) {
    final type = GameType.of(game);
    final stats = this[type];
    final t = stats.total;
    final ms = game.elapsed.inMilliseconds;
    final total = t.copyWith(
      played: t.played + 1,
      won: t.won + 1,
      streak: t.streak + 1,
      playMs: t.playMs + ms,
      bestTimeMs: !_timed(game)
          ? t.bestTimeMs
          : (t.bestTimeMs == null || ms < t.bestTimeMs! ? ms : t.bestTimeMs),
      fewestMoves: t.fewestMoves == null || game.moves < t.fewestMoves!
          ? game.moves
          : t.fewestMoves,
      highScore:
          _scores(game) && (t.highScore == null || game.score > t.highScore!)
          ? game.score
          : t.highScore,
    );
    return _with(type, _after(stats, game, total, won: true));
  }

  /// A loss (an abandoned game with a move): played up, the streak reset,
  /// its time counted, the mode and (Vegas) dollars updated.
  StatsDocument recordLoss(Game game) {
    final type = GameType.of(game);
    final stats = this[type];
    final t = stats.total;
    final total = t.copyWith(
      played: t.played + 1,
      streak: 0,
      playMs: t.playMs + game.elapsed.inMilliseconds,
    );
    return _with(type, _after(stats, game, total, won: false));
  }

  static GameStats _after(
    GameStats stats,
    Game game,
    TotalStats total, {
    required bool won,
  }) {
    final key = modeKey(game);
    final m = stats.mode(key);
    final modes = {
      ...stats.modes,
      key: ModeStats(played: m.played + 1, won: m.won + (won ? 1 : 0)),
    };
    var vegas = stats.vegas;
    if (game is KlondikeGame &&
        game.scoring == ScoringMode.vegas &&
        vegas != null) {
      vegas = VegasStats(
        played: vegas.played + 1,
        won: vegas.won + (won ? 1 : 0),
        dollars: vegas.dollars + game.score,
      );
    }
    return GameStats(total: total, modes: modes, vegas: vegas);
  }
}

/// The statistics in memory, written to the `stats` document on every
/// record. Records arriving before [load] are applied once it completes.
class StatsRecorder extends ChangeNotifier {
  StatsRecorder(this.store);

  final AppStore store;
  StatsDocument _document = StatsDocument.empty;
  bool _loaded = false;
  final List<StatsDocument Function(StatsDocument)> _queued = [];

  StatsDocument get document => _document;
  bool get loaded => _loaded;

  Future<void> load() async {
    final result = await store.read(StoreDoc.stats);
    var doc = StatsDocument.empty;
    if (result is Loaded) doc = StatsDocument.fromJson(result.data);
    for (final change in _queued) {
      doc = change(doc);
    }
    final hadQueued = _queued.isNotEmpty;
    _queued.clear();
    _document = doc;
    _loaded = true;
    notifyListeners();
    if (hadQueued) await store.write(StoreDoc.stats, doc.toJson());
  }

  Future<void> _apply(StatsDocument Function(StatsDocument) change) async {
    if (!_loaded) {
      _queued.add(change);
      return;
    }
    _document = change(_document);
    notifyListeners();
    await store.write(StoreDoc.stats, _document.toJson());
  }

  Future<void> recordWin(Game game) => _apply((d) => d.recordWin(game));

  Future<void> recordLoss(Game game) => _apply((d) => d.recordLoss(game));

  /// Clears both games. A game in progress records nothing now and counts
  /// in full when it ends (owner, /n8-plan M4 gate default).
  Future<void> resetAll() => _apply((_) => StatsDocument.empty);
}

/// Turns the controller's events into records, and settles saved games.
class StatsListener {
  StatsListener(this.controller, this.recorder, this.saves) {
    controller.events.addListener(_onEvent);
  }

  final GameController controller;
  final StatsRecorder recorder;
  final GameSaves saves;

  /// The most recent record's completion, for tests and the win card.
  Future<void> lastRecord = Future.value();

  void _onEvent() {
    final event = controller.events.value;
    switch (event) {
      case Abandoned(:final game):
        lastRecord = recorder.recordLoss(game);
      case Won(:final game):
        // Recorded first; #84's persistence then clears the slot.
        lastRecord = recorder.recordWin(game);
      case null:
        break;
    }
  }

  /// A saved game of [type] that is not the live one is being replaced from
  /// a setup screen: its loss is recorded once (if it had a move and no
  /// outcome yet) and the slot marked, so a crash cannot count it again.
  Future<void> abandonSaved(GameType type) async {
    final slot = saves.value[type];
    if (slot == null || !slot.start || slot.outcome || slot.game.isWon) return;
    // The live game: the controller's own event covers it.
    if (controller.game == slot.game) return;
    await recorder.recordLoss(slot.game);
    await saves.markRecorded(type, outcome: true);
  }

  /// After loading: a won slot never recorded (a crash between the win and
  /// the record) is recorded once and removed.
  Future<void> reconcileSaved() async {
    for (final type in GameType.values) {
      final slot = saves.value[type];
      if (slot != null && slot.game.isWon && !slot.outcome) {
        await recorder.recordWin(slot.game);
        await saves.clear(type);
      }
    }
  }

  void dispose() => controller.events.removeListener(_onEvent);
}
