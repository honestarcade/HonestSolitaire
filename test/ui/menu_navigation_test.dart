import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/game_saves.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/screens/about_app_screen.dart';
import 'package:honest_solitaire/ui/screens/about_studio_screen.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/screens/menu_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';

import 'setup_helpers.dart';

Future<GameScope> openMenu(WidgetTester tester, {AppStore? store}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: store ?? AppStore.memory(),
      showSplash: false,
      dealNumberSource: () => DealNumber(21),
    ),
  );
  await settle(tester);
  expect(find.byType(MenuScreen), findsOneWidget);
  return tester.widget<GameScope>(find.byType(GameScope));
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester, transition: true);
}

void main() {
  testWidgets(
    'the menu shows the design and every button pushes its screen; back returns to the menu',
    (tester) async {
      await openMenu(tester);
      expect(find.text('BY HONEST ARCADE · NO ADS'), findsOneWidget);
      expect(find.text('Klondike'), findsOneWidget);
      expect(find.text('Draw 1 or 3 · four foundations'), findsOneWidget);
      expect(find.text('Spider'), findsOneWidget);
      expect(find.text('1, 2 or 4 suits · ten columns'), findsOneWidget);
      expect(find.text('No ads, no tracking, open source.'), findsOneWidget);
      final routes = <String, Type>{
        'menu-klondike': NewKlondikeScreen,
        'menu-spider': NewSpiderScreen,
        'menu-stats': StatsScreen,
        'menu-howto': HowToPlayScreen,
        'menu-settings': SettingsScreen,
        'menu-about-app': AboutAppScreen,
        'menu-about-studio': AboutStudioScreen,
      };
      for (final entry in routes.entries) {
        await tapKey(tester, entry.key);
        await settle(tester, transition: true);
        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
        await back(tester);
        expect(find.byType(entry.value), findsNothing, reason: entry.key);
        expect(find.byType(MenuScreen), findsOneWidget);
      }
      // About Honest Arcade from About the app returns to About the app.
      await tapKey(tester, 'menu-about-app');
      await settle(tester, transition: true);
      await tapKey(tester, 'aboutapp-studio');
      await settle(tester, transition: true);
      expect(find.byType(AboutStudioScreen), findsOneWidget);
      await back(tester);
      expect(find.byType(AboutAppScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the resume button: none → "New game" opens New Klondike; a saved Klondike, then a saved Spider (last played wins)',
    (tester) async {
      final scope = await openMenu(tester);
      expect(find.text('New game'), findsOneWidget);
      expect(find.byKey(const Key('menu-resume-meta')), findsNothing);
      await tapKey(tester, 'menu-resume');
      await settle(tester, transition: true);
      expect(find.byType(NewKlondikeScreen), findsOneWidget);
      await back(tester);
      // A Klondike with a move gets saved; the menu listens.
      scope.controller.replaceGame(
        KlondikeGame.deal(
          DealNumber(5),
          const KlondikeOptions(draw: DrawMode.one),
        ),
      );
      scope.controller.tapPile(const StockPile(), null);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Continue Klondike'), findsOneWidget);
      expect(find.text('DRAW 1 · 1 MOVE'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Continue Klondike, draw 1, 1 move'),
        findsOneWidget,
      );
      // Then a Spider: last played wins.
      scope.controller.replaceGame(
        SpiderGame.deal(
          DealNumber(6),
          const SpiderOptions(suits: SpiderSuits.two),
        ),
      );
      scope.controller.tapPile(const StockPile(), null);
      scope.controller.tapPile(const StockPile(), null);
      await tester.pump(const Duration(seconds: 1));
      scope.controller.tapPile(const StockPile(), null);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Continue Spider'), findsOneWidget);
      expect(find.textContaining('2 SUITS · '), findsOneWidget);
      expect(
        scope.saves.value.klondike?.resumable,
        isTrue,
        reason: 'the Klondike stays saved',
      );
      await tapKey(tester, 'menu-resume');
      await settle(tester, transition: true);
      expect(find.byType(BoardView), findsOneWidget);
      expect(scope.controller.game, isA<SpiderGame>());
      expect(scope.controller.isPaused, isFalse);
    },
  );

  testWidgets(
    'Continue on a cold start reconstructs the saved game from disk, not the launch deal (#143)',
    (tester) async {
      // Nothing here comes from a live controller: this is what a real
      // cold start looks like -- a save written by a previous session,
      // read from disk by a controller that never touched it.
      final store = AppStore.memory();
      final deal = KlondikeGame.deal(
        DealNumber(77),
        const KlondikeOptions(draw: DrawMode.one),
      );
      final saved =
          (deal.apply(deal.legalMoves().first) as Applied<KlondikeGame>).game;
      await GameSaves(store).save(saved, start: true);

      final scope = await openMenu(tester, store: store);
      expect(
        scope.controller.game.dealNumber,
        isNot(saved.dealNumber),
        reason: 'the launch deal, not the saved one -- this is the cold path',
      );
      expect(find.text('Continue Klondike'), findsOneWidget);

      await tapKey(tester, 'menu-resume');
      await settle(tester, transition: true);

      expect(find.byType(BoardView), findsOneWidget);
      final resumed = scope.controller.game as KlondikeGame;
      expect(resumed.dealNumber, saved.dealNumber);
      expect(resumed.moves, saved.moves);
      expect(resumed.tableau, saved.tableau);
      expect(resumed.foundations, saved.foundations);
      expect(scope.controller.isPaused, isFalse);
      expect(scope.controller.hasMove, isTrue);
    },
  );

  testWidgets(
    'back from Settings opened via the pause card returns to the board; back on the menu pops the app',
    (tester) async {
      var pops = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') pops++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final scope = await openMenu(tester);
      await tapKey(tester, 'menu-klondike');
      await settle(tester, transition: true);
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect(find.byType(BoardView), findsOneWidget);
      expect(
        find.byType(NewKlondikeScreen),
        findsNothing,
        reason: 'the board sits directly over the menu',
      );
      await back(tester);
      expect(
        find.byKey(const Key('pause-card')),
        findsOneWidget,
        reason: 'the board\'s own back pauses',
      );
      await tapKey(tester, 'pause-settings');
      await settle(tester, transition: true);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await back(tester);
      expect(find.byType(BoardView), findsOneWidget);
      expect(scope.controller.isPaused, isTrue);
      await tapKey(tester, 'pause-menu');
      await settle(tester, transition: true);
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(pops, 0);
      await back(tester);
      expect(pops, 1, reason: 'back on the menu leaves the app');
      expect(find.byType(MenuScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the corruption banner combines two notices and stays across a return to the menu until ✕',
    (tester) async {
      final scope = await openMenu(tester);
      expect(find.byKey(const Key('menu-corruption-banner')), findsNothing);
      await scope.store.quarantine(StoreDoc.gameKlondike, 'test');
      await scope.store.quarantine(StoreDoc.stats, 'test');
      await settle(tester);
      expect(find.byKey(const Key('menu-corruption-banner')), findsOneWidget);
      expect(
        find.text("Couldn't load your saved game and statistics."),
        findsOneWidget,
      );
      await tapKey(tester, 'menu-settings');
      await settle(tester, transition: true);
      await back(tester);
      expect(
        find.byKey(const Key('menu-corruption-banner')),
        findsOneWidget,
        reason: 'stays until dismissed',
      );
      await tapKey(tester, 'menu-corruption-dismiss');
      expect(find.byKey(const Key('menu-corruption-banner')), findsNothing);
      expect(scope.store.corruptionNotices.value, isEmpty);
      expect(
        corruptionMessage({StoreDoc.settings}),
        "Couldn't load your settings.",
      );
      expect(
        corruptionMessage({
          StoreDoc.gameSpider,
          StoreDoc.stats,
          StoreDoc.settings,
        }),
        "Couldn't load your saved game, statistics and settings.",
      );
    },
  );
}
