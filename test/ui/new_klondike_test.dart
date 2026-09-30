import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/screens/loading_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';
import 'package:honest_solitaire/ui/widgets/option_panel.dart';

import 'setup_helpers.dart';

bool selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceButton>(find.byKey(Key(key))).selected;

KlondikeGame live(WidgetTester tester) =>
    (tester.widget<BoardView>(find.byType(BoardView).last).controller.game)
        as KlondikeGame;

void main() {
  testWidgets(
    'first run: Draw 3, Standard, Timed, Random; the design copy is there',
    (tester) async {
      await openScreen(tester, const NewKlondikeScreen());
      expect(find.text('New Klondike game'), findsOneWidget);
      expect(find.text('STANDARD 52-CARD DEAL'), findsOneWidget);
      expect(selected(tester, 'ksetup-draw-three'), isTrue);
      expect(selected(tester, 'ksetup-scoring-standard'), isTrue);
      expect(selected(tester, 'ksetup-timed-on'), isTrue);
      expect(selected(tester, 'ksetup-deal-random'), isTrue);
      expect(
        find.text(
          'Draw three is the classic newspaper game; draw one is kinder.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Winnable deals are drawn from solvable shuffles only.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ksetup-keep')),
        findsNothing,
        reason: 'no Klondike with a move',
      );
      expect(find.bySemanticsLabel('Cards per draw, Draw 3'), findsOneWidget);
    },
  );

  testWidgets(
    'defaults come from the last game; the Deal choice comes from Settings every visit',
    (tester) async {
      final store = AppStore.memory();
      await store.write(StoreDoc.settings, {
        'winnableOnly': true,
        'lastKlondikeOptions': {
          'draw': 'one',
          'scoring': 'vegas',
          'timed': false,
        },
      });
      await openScreen(tester, const NewKlondikeScreen(), store: store);
      expect(selected(tester, 'ksetup-draw-one'), isTrue);
      expect(selected(tester, 'ksetup-scoring-vegas'), isTrue);
      expect(selected(tester, 'ksetup-timed-off'), isTrue);
      expect(
        selected(tester, 'ksetup-deal-winnable'),
        isTrue,
        reason: 'Settings default',
      );
    },
  );

  testWidgets(
    'each choice changes the dealt game; Deal writes the last options and opens the board',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      await tapKey(tester, 'ksetup-draw-one');
      await tapKey(tester, 'ksetup-scoring-vegas');
      await tapKey(tester, 'ksetup-timed-off');
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      final game = scope.controller.game as KlondikeGame;
      expect(game.options.draw, DrawMode.one);
      expect(game.options.scoring, ScoringMode.vegas);
      expect(game.options.timed, isFalse);
      expect(game.winnable, isFalse);
      expect(game.dealNumber.value, 42);
      expect(find.byType(NewKlondikeScreen), findsNothing);
      expect(find.text('Klondike · draw 1'), findsOneWidget);
      expect(scope.settingsStore.lastKlondikeOptions.draw, DrawMode.one);
      expect(
        scope.settingsStore.lastKlondikeOptions.scoring,
        ScoringMode.vegas,
      );
      expect(scope.settingsStore.lastKlondikeOptions.timed, isFalse);
      expect(
        scope.stats.document.klondike.total.played,
        0,
        reason: 'the old game had no move',
      );
    },
  );

  testWidgets(
    'Winnable only routes to the search; a cancelled search writes nothing',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      await tapKey(tester, 'ksetup-deal-winnable');
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect(find.byType(LoadingScreen), findsOneWidget);
      await tapKey(tester, 'loading-cancel');
      await settle(tester, transition: true);
      expect(
        find.byType(NewKlondikeScreen),
        findsOneWidget,
        reason: 'back on New Klondike, choices intact',
      );
      expect(selected(tester, 'ksetup-deal-winnable'), isTrue);
      expect(scope.settingsStore.writes, 0);
      expect(scope.controller.game.dealNumber.value, 5);
    },
  );

  testWidgets(
    'Settings default applies unless overridden here; the override is not remembered',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      scope.playSettings.value = const PlaySettings(winnableOnly: true);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester, transition: true);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(builder: (_) => const NewKlondikeScreen()),
          );
      await settle(tester, transition: true);
      expect(selected(tester, 'ksetup-deal-winnable'), isTrue);
      await tapKey(tester, 'ksetup-deal-random');
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect((scope.controller.game as KlondikeGame).winnable, isFalse);
      expect(
        scope.playSettings.value.winnableOnly,
        isTrue,
        reason: 'the override is per visit',
      );
    },
  );

  testWidgets(
    'Keep playing appears once the live Klondike has a move and resumes it, unpaused, on its board',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      expect(find.byKey(const Key('ksetup-keep')), findsNothing);
      drawFromStock(scope);
      scope.controller.pause();
      await settle(tester);
      expect(find.byKey(const Key('ksetup-keep')), findsOneWidget);
      final before = scope.controller.game;
      await tapKey(tester, 'ksetup-keep');
      await settle(tester, transition: true);
      expect(find.byType(NewKlondikeScreen), findsNothing);
      expect(
        find.byType(BoardView),
        findsOneWidget,
        reason: 'back on the board below, not a new one',
      );
      expect(scope.controller.game, before);
      expect(scope.controller.isPaused, isFalse);
      expect(scope.stats.document.klondike.total.played, 0);
    },
  );

  testWidgets('Keep playing wears the screen\'s teal accent (#154)', (
    tester,
  ) async {
    final scope = await openScreen(tester, const NewKlondikeScreen());
    drawFromStock(scope);
    await settle(tester);
    final c = keepPlayingColours(tester, 'ksetup-keep');
    expect(
      c.border,
      SetupAccent.teal.border,
      reason: 'outlined in the accent, not grey',
    );
    expect(
      c.text,
      SetupAccent.teal.text,
      reason: 'labelled in the accent, not grey',
    );
  });

  testWidgets(
    'dealing over an unfinished Klondike records one loss; a saved Klondike behind a live Spider too',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      drawFromStock(scope);
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      await scope.statsListener.lastRecord;
      expect(scope.stats.document.klondike.total.played, 1);
      expect(scope.stats.document.klondike.total.won, 0);
      // Now the live game is a fresh Klondike; save a Spider as live and put a
      // Klondike with a move in its slot.
      final klondike = scope.controller.game;
      drawFromStock(scope);
      await tester.pump(const Duration(seconds: 1));
      await scope.store.flush();
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(9)));
      await tester.pump(const Duration(seconds: 1));
      expect(scope.saves.value.klondike?.resumable, isTrue);
      expect(scope.saves.value.klondike?.game.dealNumber, klondike.dealNumber);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(builder: (_) => const NewKlondikeScreen()),
          );
      await settle(tester, transition: true);
      expect(
        find.byKey(const Key('ksetup-keep')),
        findsOneWidget,
        reason: 'the saved Klondike is resumable',
      );
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      await tester.pump(const Duration(seconds: 1));
      expect(
        scope.stats.document.klondike.total.played,
        2,
        reason: 'the saved slot lost once',
      );
      expect(
        scope.stats.document.spider.total.played,
        0,
        reason: 'the Spider is untouched',
      );
      expect(scope.saves.value.spider?.game.dealNumber.value, 9);
    },
  );
}
