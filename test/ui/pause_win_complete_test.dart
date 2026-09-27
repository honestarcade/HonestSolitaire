import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/stats.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/finish_sweep.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/navigation.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/screens/menu_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';
import 'package:honest_solitaire/ui/widgets/game_tabs.dart';

import 'setup_helpers.dart';
import 'win_fixtures.dart';

/// The app on a board showing [game].
Future<GameScope> openBoardWith(
  WidgetTester tester,
  Game game, {
  AppStore? store,
  Size logical = const Size(390, 844),
}) async {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: store ?? AppStore.memory(),
      showSplash: false,
      dealNumberSource: () => DealNumber(77),
    ),
  );
  await settle(tester);
  final scope = tester.widget<GameScope>(find.byType(GameScope));
  scope.controller.replaceGame(game);
  tester.state<NavigatorState>(find.byType(Navigator)).push(boardRoute());
  await settle(tester, transition: true);
  return scope;
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester, transition: true);
}

void main() {
  testWidgets(
    'the pause card has Rules, Settings and Main menu, no Switch; Rules and Settings return to the board paused',
    (tester) async {
      final scope = await openBoardWith(
        tester,
        SpiderGame.deal(
          DealNumber(3),
          const SpiderOptions(suits: SpiderSuits.two),
        ),
      );
      scope.controller.tapPile(const StockPile(), null);
      scope.controller.pause();
      await settle(tester);
      for (final label in [
        'Resume',
        'Restart this deal',
        'New deal',
        'Rules',
        'Settings',
        'Main menu',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('Switch to'), findsNothing);
      await tapKey(tester, 'pause-rules');
      await settle(tester, transition: true);
      expect(find.byType(HowToPlayScreen), findsOneWidget);
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.spider,
        reason: 'this game\'s tab',
      );
      await back(tester);
      expect(find.byType(HowToPlayScreen), findsNothing);
      expect(find.byType(BoardView), findsOneWidget);
      expect(scope.controller.isPaused, isTrue);
      expect(find.byKey(const Key('pause-card')), findsOneWidget);
      await tapKey(tester, 'pause-settings');
      await settle(tester, transition: true);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await back(tester);
      expect(find.byType(BoardView), findsOneWidget);
      expect(scope.controller.isPaused, isTrue);
    },
  );

  testWidgets(
    'Main menu keeps the game resumable, records no loss, and Continue brings it back unpaused',
    (tester) async {
      final scope = await openBoardWith(
        tester,
        KlondikeGame.deal(
          DealNumber(9),
          const KlondikeOptions(draw: DrawMode.three),
        ),
      );
      scope.controller.tapPile(const StockPile(), null);
      scope.controller.pause();
      await settle(tester);
      final played = scope.controller.game;
      await tapKey(tester, 'pause-menu');
      await settle(tester, transition: true);
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(find.byType(BoardView), findsNothing);
      expect(scope.stats.document.klondike.total.played, 0, reason: 'no loss');
      expect(scope.controller.game, played);
      expect(
        scope.saves.value.klondike?.resumable,
        isTrue,
        reason: 'flushed before leaving',
      );
      expect(find.text('Continue Klondike'), findsOneWidget);
      expect(find.text('DRAW 3 · 1 MOVE'), findsOneWidget);
      await tapKey(tester, 'menu-resume');
      await settle(tester, transition: true);
      expect(find.byType(BoardView), findsOneWidget);
      expect(scope.controller.game, played, reason: 'the live game is reused');
      expect(scope.controller.isPaused, isFalse);
    },
  );

  testWidgets(
    'the win card shows the streak after the win is recorded; See statistics opens this tab and back returns to the win card; Main menu offers no Continue',
    (tester) async {
      final store = AppStore.memory();
      await store.write(
        StoreDoc.stats,
        const StatsDocument(
          klondike: GameStats(total: TotalStats(played: 6, won: 4, streak: 4)),
        ).toJson(),
      );
      final scope = await openBoardWith(
        tester,
        nearWin(const KlondikeOptions()),
        store: store,
      );
      scope.controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await settle(tester);
      await tester.pump(winCardDelay);
      await settle(tester);
      expect(find.byKey(const Key('win-card')), findsOneWidget);
      expect(scope.stats.document.klondike.total.streak, 5);
      expect(find.text('STREAK'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('win-cell-streak')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      final cells = find.byKey(const Key('win-card')).evaluate().first;
      expect(cells, isNotNull);
      expect(find.text('TIME BONUS'), findsOneWidget);
      await tapKey(tester, 'win-stats');
      await settle(tester, transition: true);
      expect(find.byType(StatsScreen), findsOneWidget);
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.klondike,
      );
      await back(tester);
      expect(find.byKey(const Key('win-card')), findsOneWidget);
      await tapKey(tester, 'win-menu');
      await settle(tester, transition: true);
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(
        find.text('New game'),
        findsOneWidget,
        reason: 'the won slot was cleared',
      );
    },
  );

  testWidgets(
    'NEW, New deal on the pause card and New deal on the win card open the right setup screen; back returns to the board as it was',
    (tester) async {
      final scope = await openBoardWith(
        tester,
        KlondikeGame.deal(DealNumber(9)),
      );
      await tapKey(tester, 'tool-new');
      await settle(tester, transition: true);
      expect(find.byType(NewKlondikeScreen), findsOneWidget);
      expect(scope.controller.isPaused, isTrue, reason: 'paused first');
      await back(tester);
      expect(find.byKey(const Key('pause-card')), findsOneWidget);
      await tapKey(tester, 'pause-new');
      await settle(tester, transition: true);
      expect(find.byType(NewKlondikeScreen), findsOneWidget);
      expect(
        find.byKey(const Key('ksetup-keep')),
        findsNothing,
        reason: 'no move yet',
      );
      await back(tester);
      expect(find.byKey(const Key('pause-card')), findsOneWidget);
      // Spider → New Spider.
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(4)));
      await settle(tester);
      await tapKey(tester, 'tool-new');
      await settle(tester, transition: true);
      expect(find.byType(NewSpiderScreen), findsOneWidget);
      await back(tester);
      // A win → New deal opens the setup screen with Keep playing hidden.
      scope.controller.replaceGame(nearWin(const KlondikeOptions()));
      await settle(tester);
      scope.controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump(winCardDelay);
      await settle(tester);
      await tapKey(tester, 'win-new');
      await settle(tester, transition: true);
      expect(find.byType(NewKlondikeScreen), findsOneWidget);
      expect(
        find.byKey(const Key('ksetup-keep')),
        findsNothing,
        reason: 'the game is won',
      );
      await back(tester);
      expect(find.byKey(const Key('win-card')), findsOneWidget);
    },
  );

  testWidgets('on a 320×568 phone both cards fit without overflow', (
    tester,
  ) async {
    final scope = await openBoardWith(
      tester,
      KlondikeGame.deal(DealNumber(9)),
      logical: const Size(320, 568),
    );
    scope.controller.pause();
    await settle(tester);
    expect(find.byKey(const Key('pause-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
    scope.controller.replaceGame(nearWin(const KlondikeOptions()));
    await settle(tester);
    scope.controller.move(
      const TableauPile(0),
      0,
      const FoundationPile(Suit.clubs),
    );
    await tester.pump(winCardDelay);
    await settle(tester);
    expect(find.byKey(const Key('win-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
