import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/game_saves.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';

GameController controllerFor(Game game) => GameController(
  game,
  ValueNotifier(const PlaySettings(oneTap: false)),
  ValueNotifier(const DisplayOptions()),
  observeLifecycle: false,
);

Game played(Game game, int moves) {
  var g = game;
  for (var i = 0; i < moves; i++) {
    final legal = g.legalMoves();
    g = applied(g, legal[i % legal.length]);
  }
  return g;
}

void main() {
  group('GameSaves', () {
    test('a saved game of each type loads back exactly, undo included, with lastPlayed', () async {
      final store = AppStore.memory();
      final saves = GameSaves(store, now: () => 1000);
      final k = played(
        KlondikeGame.deal(
          DealNumber(7),
          const KlondikeOptions(draw: DrawMode.three),
        ),
        8,
      ).tick(const Duration(seconds: 40));
      final s = played(
        SpiderGame.deal(
          DealNumber(12),
          const SpiderOptions(suits: SpiderSuits.two),
        ),
        5,
      );
      await saves.save(k, start: true);
      await saves.save(s, start: true);
      final again = GameSaves(store);
      await again.load();
      expect(again.value.klondike!.game, k);
      expect(again.value.klondike!.game.elapsed, k.elapsed);
      expect(again.value.klondike!.game.historyLength, 8);
      expect(again.value.klondike!.start, isTrue);
      expect(again.value.klondike!.outcome, isFalse);
      expect(again.value.spider!.game, s);
      expect(again.value.lastPlayed, GameType.spider);
      expect(again.value.resumeTarget!.game, s);
      final back = (again.value.klondike!.game.undo(
        unlimited: true,
      ) as Applied<Game>).game;
      expect(back.moves, 7);
    });

    test(
      'a corrupt slot is quarantined and absent; a wrong-type slot too',
      () async {
        final store = AppStore.memory();
        await store.write(StoreDoc.gameKlondike, {
          'game': {'format': 1, 'game': 'klondike', 'deal': 999},
        });
        await store.write(StoreDoc.gameSpider, {
          'game': KlondikeGame.deal(DealNumber(1)).toJson(),
        });
        final saves = GameSaves(store);
        await saves.load();
        expect(saves.value.klondike, isNull);
        expect(saves.value.spider, isNull);
        expect(store.corruptionNotices.value, {
          StoreDoc.gameKlondike,
          StoreDoc.gameSpider,
        });
        expect(await store.read(StoreDoc.gameKlondike), isA<Absent>());
      },
    );

    test('a slot already recorded is deleted; a won unrecorded slot is kept for stats but not resumable', () async {
      final store = AppStore.memory();
      final g = played(KlondikeGame.deal(DealNumber(3)), 2);
      await store.write(StoreDoc.gameKlondike, {
        'game': g.toJson(),
        'recorded': {'start': true, 'outcome': true},
        'savedAt': 5,
      });
      final won = applied(
        klondike(
          tableau: [cards('KC'), [], [], [], [], [], []],
          foundations: [
            suitRun(Suit.spades, 13),
            suitRun(Suit.hearts, 13),
            suitRun(Suit.diamonds, 13),
            suitRun(Suit.clubs, 12),
          ],
        ),
        const TableauToFoundation(0),
      );
      // A fromPiles game cannot be saved (no history from a deal); use a real
      // near-win: dealt game replayed to a win is not available here, so the
      // won-slot rule is asserted through SavedGame directly.
      final wonSlot = SavedGame(
        game: won,
        start: true,
        outcome: false,
        savedAt: 1,
      );
      expect(wonSlot.resumable, isFalse);
      final saves = GameSaves(store);
      await saves.load();
      expect(saves.value.klondike, isNull, reason: 'recorded games go');
      expect(await store.read(StoreDoc.gameKlondike), isA<Absent>());
      expect(store.corruptionNotices.value, isEmpty);
    });

    test(
      'lastPlayed falls back to the newer save when meta is missing',
      () async {
        final store = AppStore.memory();
        var t = 10;
        final saves = GameSaves(store, now: () => t++);
        await saves.save(SpiderGame.deal(DealNumber(1)), start: false);
        await saves.save(KlondikeGame.deal(DealNumber(1)), start: false);
        await store.delete(StoreDoc.meta);
        final again = GameSaves(store);
        await again.load();
        expect(again.value.lastPlayed, GameType.klondike);
        expect(again.value.resumeTarget, isNull, reason: 'no game has a move');
      },
    );

    test('markRecorded rewrites the flags; clear removes the slot', () async {
      final store = AppStore.memory();
      final saves = GameSaves(store);
      await saves.save(KlondikeGame.deal(DealNumber(2)), start: false);
      await saves.markRecorded(GameType.klondike, start: true);
      final again = GameSaves(store);
      await again.load();
      expect(again.value.klondike!.start, isTrue);
      await saves.clear(GameType.klondike);
      expect(saves.value.klondike, isNull);
      expect(await store.read(StoreDoc.gameKlondike), isA<Absent>());
    });
  });

  group('GamePersistence', () {
    testWidgets(
      'the leading change writes at once; twenty rapid moves write at most one per 500 ms plus a trailing one',
      (tester) async {
        final store = AppStore.memory();
        final saves = GameSaves(store);
        final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
        final persistence = GamePersistence(
          controller,
          saves,
          observeLifecycle: false,
        );
        controller.tapPile(const StockPile(), null);
        expect(persistence.writes, 1, reason: 'the leading write');
        for (var i = 0; i < 19; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          controller.tapPile(const StockPile(), null);
        }
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          persistence.writes,
          lessThanOrEqualTo(1 + 2 + 1),
          reason: '1 s of moves at 500 ms windows',
        );
        expect(persistence.writes, greaterThanOrEqualTo(2));
        expect(
          saves.value.klondike!.game,
          controller.game,
          reason: 'the trailing write carried the latest game',
        );
        persistence.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'a background event flushes the pending save at once, with the clock flushed',
      (tester) async {
        final store = AppStore.memory();
        final saves = GameSaves(store);
        final controller = GameController(
          KlondikeGame.deal(DealNumber(7)),
          ValueNotifier(const PlaySettings(oneTap: false)),
          ValueNotifier(const DisplayOptions()),
          clockNow: () => const Duration(seconds: 0),
        );
        final persistence = GamePersistence(controller, saves);
        controller.tapPile(const StockPile(), null);
        await tester.pump(const Duration(milliseconds: 100));
        controller.tapPile(const StockPile(), null);
        expect(persistence.writes, 1, reason: 'the second move is pending');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(persistence.writes, 2);
        expect(saves.value.klondike!.game.moves, 2);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 1));
        persistence.dispose();
        controller.dispose();
      },
    );

    testWidgets('a win clears the slot and nothing resurrects it', (
      tester,
    ) async {
      final store = AppStore.memory();
      final saves = GameSaves(store);
      final near = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 12),
        ],
      );
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      final persistence = GamePersistence(
        controller,
        saves,
        observeLifecycle: false,
      );
      controller.tapPile(const StockPile(), null);
      await tester.pump(const Duration(milliseconds: 600));
      expect(saves.value.klondike, isNotNull);
      controller.replaceGame(
        near,
      ); // a fromPiles game: saving it would fail to replay, but it is won next
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.game.isWon, isTrue);
      expect(saves.value.klondike, isNull);
      await store.flush();
      expect(await store.read(StoreDoc.gameKlondike), isA<Absent>());
      persistence.dispose();
      controller.dispose();
    });

    // One move from solved-but-not-won: the move that solves it starts the
    // auto-finish sweep, which is how most Klondike games are won (#152).
    KlondikeGame twoToGo() => klondike(
      tableau: [cards('KC'), cards('QC'), [], [], [], [], []],
      foundations: [
        suitRun(Suit.spades, 13),
        suitRun(Suit.hearts, 13),
        suitRun(Suit.diamonds, 13),
        suitRun(Suit.clubs, 11),
      ],
    );

    for (final (route, autoFinish) in [
      ('auto-finish', true),
      ('FINISH', false),
    ]) {
      testWidgets(
        'a win reached through $route clears the slot and offers no resume (#152)',
        (tester) async {
          final store = AppStore.memory();
          final saves = GameSaves(store);
          final controller = GameController(
            KlondikeGame.deal(DealNumber(7)),
            ValueNotifier(PlaySettings(oneTap: false, autoFinish: autoFinish)),
            ValueNotifier(const DisplayOptions()),
            observeLifecycle: false,
          );
          final persistence = GamePersistence(
            controller,
            saves,
            observeLifecycle: false,
          );
          controller.tapPile(const StockPile(), null);
          await tester.pump(const Duration(milliseconds: 600));
          controller.replaceGame(twoToGo());
          controller.move(
            const TableauPile(1),
            0,
            const FoundationPile(Suit.clubs),
          );
          await tester.pump(const Duration(milliseconds: 600));
          if (!autoFinish) {
            expect(controller.canFinish, isTrue);
            controller.finish();
          }
          await tester.pump(const Duration(seconds: 3));
          expect(controller.game.isWon, isTrue, reason: 'won via $route');
          expect(
            saves.value.klondike,
            isNull,
            reason: 'a won game leaves no slot behind ($route)',
          );
          expect(
            saves.value.resumeTarget,
            isNull,
            reason: 'Continue must not offer the pre-finish board ($route)',
          );
          await store.flush();
          expect(await store.read(StoreDoc.gameKlondike), isA<Absent>());
          persistence.dispose();
          controller.dispose();
        },
      );
    }

    testWidgets(
      'undo, restart and a new deal save; a resumed game records nothing and keeps hasMove',
      (tester) async {
        final store = AppStore.memory();
        final saves = GameSaves(store);
        final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
        final persistence = GamePersistence(
          controller,
          saves,
          observeLifecycle: false,
        );
        final events = <GameEvent>[];
        controller.events.addListener(
          () => events.add(controller.events.value!),
        );
        controller.tapPile(const StockPile(), null);
        await tester.pump(const Duration(milliseconds: 600));
        controller.undo();
        await tester.pump(const Duration(milliseconds: 600));
        expect(saves.value.klondike!.game.moves, 0);
        expect(
          saves.value.klondike!.start,
          isTrue,
          reason: 'has-move is sticky across undo',
        );
        controller.restart();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          events.whereType<Abandoned>().single.reason,
          AbandonReason.restart,
        );
        expect(saves.value.klondike!.start, isFalse);
        controller.tapPile(const StockPile(), null);
        controller.replaceGame(KlondikeGame.deal(DealNumber(8)));
        await tester.pump(const Duration(milliseconds: 600));
        expect(events.whereType<Abandoned>(), hasLength(2));
        expect(saves.value.klondike!.game.dealNumber.value, 8);
        // Switching type abandons nothing.
        controller.replaceGame(SpiderGame.deal(DealNumber(1)));
        await tester.pump(const Duration(milliseconds: 600));
        expect(events.whereType<Abandoned>(), hasLength(2));
        expect(saves.value.spider, isNotNull);
        expect(
          saves.value.klondike,
          isNotNull,
          reason: 'the other type stays resumable',
        );
        // Resume records nothing and carries the flag.
        final saved = saves.value.klondike!;
        controller.resumeGame(saved.game, hasMove: true);
        expect(controller.hasMove, isTrue);
        expect(controller.clock.running, isFalse);
        await tester.pump(const Duration(milliseconds: 600));
        expect(events, hasLength(2));
        persistence.dispose();
        controller.dispose();
      },
    );
  });
}
