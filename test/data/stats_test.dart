import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/game_saves.dart';
import 'package:honest_solitaire/data/stats.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/engine/solver.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';

Game played(Game game, int moves) {
  var g = game;
  for (var i = 0; i < moves; i++) {
    final legal = g.legalMoves();
    g = applied(g, legal[i % legal.length]);
  }
  return g;
}

/// A Klondike win in [options] taking [seconds] and [moves] (a hand-built
/// position, then the winning move).
KlondikeGame klondikeWin(
  KlondikeOptions options, {
  int seconds = 120,
  int moves = 99,
  int moveScore = 100,
}) => applied(
  klondike(
    tableau: [cards('KC'), [], [], [], [], [], []],
    foundations: [
      suitRun(Suit.spades, 13),
      suitRun(Suit.hearts, 13),
      suitRun(Suit.diamonds, 13),
      suitRun(Suit.clubs, 12),
    ],
    options: options,
    moveScore: moveScore,
    moves: moves,
    elapsed: Duration(seconds: seconds),
  ),
  const TableauToFoundation(0),
);

SpiderGame spiderWin({int seconds = 300, int moves = 200}) => applied(
  spider(
    tableau: [
      kingDown(Suit.spades, 2),
      cards('AS'),
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
    ],
    completed: List.filled(7, Suit.spades),
    moveScore: 700,
    moves: moves,
    elapsed: Duration(seconds: seconds),
  ),
  const MoveCards(1, 0, 0),
);

KlondikeGame inProgress(
  KlondikeOptions options, {
  int seconds = 30,
  int moves = 4,
}) => klondike(
  tableau: [cards('KS'), [], [], [], [], [], []],
  options: options,
  moves: moves,
  elapsed: Duration(seconds: seconds),
);

GameController controllerFor(Game game) => GameController(
  game,
  ValueNotifier(const PlaySettings(oneTap: false)),
  ValueNotifier(const DisplayOptions()),
  observeLifecycle: false,
);

void main() {
  group('the rules', () {
    test('a win counts played, won, streak, time, best time, fewest moves and high score', () {
      var d = StatsDocument.empty;
      d = d.recordWin(
        klondikeWin(
          const KlondikeOptions(),
          seconds: 120,
          moves: 99,
          moveScore: 100,
        ),
      );
      final t = d.klondike.total;
      expect(t.played, 1);
      expect(t.won, 1);
      expect(t.streak, 1);
      expect(t.playMs, 120000);
      expect(t.bestTimeMs, 120000);
      expect(t.fewestMoves, 100);
      expect(
        t.highScore,
        110 - 24 + 5833,
        reason: 'the shown score, bonus included',
      );
      expect(d.klondike.mode('draw1').played, 1);
      expect(d.klondike.mode('draw1').won, 1);
      expect(d.klondike.mode('draw3').played, 0);
      expect(d.klondike.vegas!.played, 0);
      expect(d.spider.total.played, 0);
    });

    test(
      'a loss counts played and time, resets the streak, and touches no record',
      () {
        var d = StatsDocument.empty
            .recordWin(klondikeWin(const KlondikeOptions()))
            .recordWin(klondikeWin(const KlondikeOptions()));
        expect(d.klondike.total.streak, 2);
        d = d.recordLoss(
          inProgress(
            const KlondikeOptions(draw: DrawMode.three),
            seconds: 30,
            moves: 4,
          ),
        );
        expect(d.klondike.total.played, 3);
        expect(d.klondike.total.won, 2);
        expect(d.klondike.total.streak, 0);
        expect(d.klondike.total.playMs, 240000 + 30000);
        expect(d.klondike.total.fewestMoves, 100);
        expect(d.klondike.mode('draw3').played, 1);
        expect(d.klondike.mode('draw3').won, 0);
        d = d.recordWin(klondikeWin(const KlondikeOptions()));
        expect(
          d.klondike.total.streak,
          1,
          reason: 'a streak restarts after a loss',
        );
      },
    );

    test('three wins in a row give streak 3', () {
      var d = StatsDocument.empty;
      for (var i = 0; i < 3; i++) {
        d = d.recordWin(spiderWin());
      }
      expect(d.spider.total.streak, 3);
      expect(d.spider.mode('one').won, 3);
    });

    test('best time ignores untimed wins and slower wins', () {
      var d = StatsDocument.empty.recordWin(
        klondikeWin(const KlondikeOptions(), seconds: 120),
      );
      d = d.recordWin(
        klondikeWin(const KlondikeOptions(timed: false), seconds: 10),
      );
      expect(
        d.klondike.total.bestTimeMs,
        120000,
        reason: 'untimed never sets it',
      );
      d = d.recordWin(klondikeWin(const KlondikeOptions(), seconds: 200));
      expect(d.klondike.total.bestTimeMs, 120000);
      d = d.recordWin(klondikeWin(const KlondikeOptions(), seconds: 90));
      expect(d.klondike.total.bestTimeMs, 90000);
      expect(
        d.klondike.total.playMs,
        420000,
        reason: 'total play time includes the untimed win',
      );
    });

    test('fewest moves updates only downward', () {
      var d = StatsDocument.empty.recordWin(
        klondikeWin(const KlondikeOptions(), moves: 99),
      );
      d = d.recordWin(klondikeWin(const KlondikeOptions(), moves: 150));
      expect(d.klondike.total.fewestMoves, 100);
      d = d.recordWin(klondikeWin(const KlondikeOptions(), moves: 60));
      expect(d.klondike.total.fewestMoves, 61);
    });

    test('Vegas wins and losses add lifetime dollars and never set a high score; none scores nothing', () {
      var d = StatsDocument.empty;
      d = d.recordWin(
        klondikeWin(
          const KlondikeOptions(scoring: ScoringMode.vegas),
          moveScore: 40,
        ),
      );
      expect(d.klondike.vegas!.dollars, 45);
      expect(d.klondike.vegas!.played, 1);
      expect(d.klondike.vegas!.won, 1);
      expect(d.klondike.total.highScore, isNull);
      d = d.recordLoss(
        inProgress(
          const KlondikeOptions(scoring: ScoringMode.vegas),
          moves: 3,
        ).tick(Duration.zero),
      );
      // The in-progress Vegas game holds the deal's −52.
      expect(d.klondike.vegas!.dollars, 45 - 52);
      expect(d.klondike.vegas!.played, 2);
      expect(d.klondike.total.played, 2);
      d = d.recordWin(
        klondikeWin(const KlondikeOptions(scoring: ScoringMode.none)),
      );
      expect(d.klondike.total.highScore, isNull);
      expect(d.klondike.total.won, 2);
    });

    test('Spider scores set the high score; reset empties both games', () {
      var d = StatsDocument.empty.recordWin(spiderWin());
      expect(d.spider.total.highScore, 700 - 1 + 100 + 700000 ~/ 300);
      d = d.recordWin(klondikeWin(const KlondikeOptions()));
      d = StatsDocument.empty;
      expect(d.spider.total.played, 0);
      expect(d.klondike.total.played, 0);
      expect(d.klondike.total.highScore, isNull);
    });

    test(
      'the document round-trips through JSON and tolerates damage per field',
      () {
        final d = StatsDocument.empty
            .recordWin(
              klondikeWin(
                const KlondikeOptions(scoring: ScoringMode.vegas),
                moveScore: 40,
              ),
            )
            .recordWin(spiderWin())
            .recordLoss(inProgress(const KlondikeOptions()));
        final back = StatsDocument.fromJson(d.toJson());
        expect(back.toJson(), d.toJson());
        final damaged = StatsDocument.fromJson({
          'klondike': {
            'total': {
              'played': 2,
              'won': 5,
              'streak': -1,
              'bestTimeMs': 'x',
              'highScore': 12,
            },
            'modes': {
              'draw1': {'played': 1},
              'bogus': {},
            },
            'vegas': {'dollars': -30},
          },
          'spider': 'nope',
        });
        expect(damaged.klondike.total.played, 2);
        expect(damaged.klondike.total.won, 2, reason: 'clamped to played');
        expect(damaged.klondike.total.streak, 0);
        expect(damaged.klondike.total.bestTimeMs, isNull);
        expect(damaged.klondike.total.highScore, 12);
        expect(damaged.klondike.modes.keys, ['draw1']);
        expect(damaged.klondike.vegas!.dollars, -30);
        expect(damaged.spider.total.played, 0);
      },
    );
  });

  group('the recorder and the listener', () {
    test(
      'records persist; records before load are queued and applied after it',
      () async {
        final store = AppStore.memory();
        final recorder = StatsRecorder(store);
        final win = recorder.recordWin(spiderWin());
        expect(recorder.document.spider.total.won, 0, reason: 'queued');
        await recorder.load();
        await win;
        expect(recorder.document.spider.total.won, 1);
        final again = StatsRecorder(store);
        await again.load();
        expect(again.document.spider.total.won, 1);
        await again.resetAll();
        final third = StatsRecorder(store);
        await third.load();
        expect(third.document.spider.total.played, 0);
      },
    );

    test('a game with no move then a new deal records nothing; one move then a new deal records a loss', () async {
      final store = AppStore.memory();
      final recorder = StatsRecorder(store);
      await recorder.load();
      final saves = GameSaves(store);
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      final listener = StatsListener(controller, recorder, saves);
      controller.replaceGame(KlondikeGame.deal(DealNumber(8)));
      await listener.lastRecord;
      expect(recorder.document.klondike.total.played, 0);
      controller.tapPile(const StockPile(), null);
      controller.replaceGame(KlondikeGame.deal(DealNumber(9)));
      await listener.lastRecord;
      expect(recorder.document.klondike.total.played, 1);
      expect(recorder.document.klondike.total.won, 0);
      expect(recorder.document.klondike.mode('draw1').played, 1);
      // A restart after a move records a loss too; the other type's deal does not.
      controller.tapPile(const StockPile(), null);
      controller.restart();
      await listener.lastRecord;
      expect(recorder.document.klondike.total.played, 2);
      controller.tapPile(const StockPile(), null);
      controller.replaceGame(SpiderGame.deal(DealNumber(1)));
      await listener.lastRecord;
      expect(
        recorder.document.klondike.total.played,
        2,
        reason: 'switching type is not abandoning',
      );
      listener.dispose();
      controller.dispose();
    });

    test('a win records once through the listener, with its streak', () async {
      final store = AppStore.memory();
      final recorder = StatsRecorder(store);
      await recorder.load();
      final saves = GameSaves(store);
      final controller = controllerFor(inProgress(const KlondikeOptions()));
      final listener = StatsListener(controller, recorder, saves);
      final near = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 12),
        ],
      );
      controller.resumeGame(near, hasMove: true);
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await listener.lastRecord;
      expect(recorder.document.klondike.total.won, 1);
      expect(recorder.document.klondike.total.streak, 1);
      expect(
        recorder.document.klondike.total.played,
        1,
        reason: 'resume recorded nothing',
      );
      listener.dispose();
      controller.dispose();
    });

    test('an app restart with a saved game records nothing; finishing it later records once', () async {
      final store = AppStore.memory();
      final recorder = StatsRecorder(store);
      await recorder.load();
      final saves = GameSaves(store);
      // The saved game: had a move, no outcome.
      final saved = played(KlondikeGame.deal(DealNumber(7)), 3);
      await saves.save(saved, start: true);
      final controller = controllerFor(saved);
      final listener = StatsListener(controller, recorder, saves);
      controller.resumeGame(saved, hasMove: true);
      expect(recorder.document.klondike.total.played, 0);
      await listener.reconcileSaved();
      expect(recorder.document.klondike.total.played, 0);
      // Later: a new deal over it counts the loss once.
      controller.replaceGame(KlondikeGame.deal(DealNumber(8)));
      await listener.lastRecord;
      expect(recorder.document.klondike.total.played, 1);
      listener.dispose();
      controller.dispose();
    });

    test('a crash between a win and its record: relaunch reconciles it once, from a fresh recorder and listener (#141)', () async {
      final store = AppStore.memory();
      // Session 1: the game is won and saved, but the app is killed
      // before StatsListener's own event ever records it -- no
      // controller, no listener, nothing but the win landing on disk.
      // A genuinely dealt-and-solved win, not a hand-built position: the
      // saved slot must survive a real reload, which replays history
      // from the deal number and refuses a position that does not
      // follow from it.
      final deal = KlondikeGame.deal(DealNumber(1));
      final solved = solve(deal) as Solved;
      var won = deal;
      for (final move in solved.moves) {
        won = (won.apply(move) as Applied<KlondikeGame>).game;
      }
      expect(won.isWon, isTrue);
      final saves1 = GameSaves(store);
      await saves1.save(won, start: true, outcome: false);

      // Session 2 ("relaunch"): every object is new, reading the same
      // store -- the real launch order in app.dart (saves.load() then
      // reconcileSaved()), not the live-controller path #85's other
      // tests exercise.
      final recorder = StatsRecorder(store);
      await recorder.load();
      expect(
        recorder.document.klondike.total.played,
        0,
        reason: 'nothing recorded yet',
      );
      final saves2 = GameSaves(store);
      await saves2.load();
      expect(saves2.value.klondike?.game.isWon, isTrue);
      expect(saves2.value.klondike?.outcome, isFalse);
      final controller = controllerFor(KlondikeGame.deal(DealNumber(9)));
      final listener = StatsListener(controller, recorder, saves2);

      await listener.reconcileSaved();

      expect(
        recorder.document.klondike.total.played,
        1,
        reason: 'the win is recorded on relaunch, not lost',
      );
      expect(recorder.document.klondike.total.won, 1);
      expect(
        saves2.value.klondike,
        isNull,
        reason: 'the reconciled slot is cleared',
      );

      // A second relaunch (or a second call) reconciles nothing further:
      // the slot is gone, so there is nothing left to double-count.
      final saves3 = GameSaves(store);
      await saves3.load();
      final listener2 = StatsListener(
        controllerFor(KlondikeGame.deal(DealNumber(10))),
        recorder,
        saves3,
      );
      await listener2.reconcileSaved();
      expect(recorder.document.klondike.total.played, 1, reason: 'once');

      listener.dispose();
      listener2.dispose();
      controller.dispose();
    });

    test('abandonSaved records a saved slot once and marks it; a won unrecorded slot is reconciled', () async {
      final store = AppStore.memory();
      final recorder = StatsRecorder(store);
      await recorder.load();
      final saves = GameSaves(store);
      await saves.save(played(SpiderGame.deal(DealNumber(2)), 2), start: true);
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      final listener = StatsListener(controller, recorder, saves);
      await listener.abandonSaved(GameType.spider);
      expect(recorder.document.spider.total.played, 1);
      expect(saves.value.spider!.outcome, isTrue);
      await listener.abandonSaved(GameType.spider);
      expect(recorder.document.spider.total.played, 1, reason: 'once');
      await saves.save(KlondikeGame.deal(DealNumber(3)), start: false);
      await listener.abandonSaved(GameType.klondike);
      expect(
        recorder.document.klondike.total.played,
        0,
        reason: 'no move, no loss',
      );
      listener.dispose();
      controller.dispose();
    });

    test('reset records nothing for the game in progress, which then counts in full', () async {
      final store = AppStore.memory();
      final recorder = StatsRecorder(store);
      await recorder.load();
      final saves = GameSaves(store);
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      final listener = StatsListener(controller, recorder, saves);
      controller.tapPile(const StockPile(), null);
      await recorder.resetAll();
      expect(recorder.document.klondike.total.played, 0);
      controller.tapPile(const StockPile(), null);
      controller.replaceGame(KlondikeGame.deal(DealNumber(8)));
      await listener.lastRecord;
      expect(
        recorder.document.klondike.total.played,
        1,
        reason: 'counted once, in full, when it ended',
      );
      listener.dispose();
      controller.dispose();
    });
  });
}
