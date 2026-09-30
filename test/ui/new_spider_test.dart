import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/widgets/option_panel.dart';

import 'setup_helpers.dart';

bool selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceButton>(find.byKey(Key(key))).selected;

void main() {
  testWidgets(
    'first run: Two suits, Timed, Strict; the design copy; no winnable control',
    (tester) async {
      await openScreen(tester, const NewSpiderScreen());
      expect(find.text('New Spider game'), findsOneWidget);
      expect(find.text('TWO DECKS · 104 CARDS'), findsOneWidget);
      expect(selected(tester, 'ssetup-suits-two'), isTrue);
      expect(selected(tester, 'ssetup-timed-on'), isTrue);
      expect(selected(tester, 'ssetup-rule-strict'), isTrue);
      expect(find.text('Spiderette. A gentle warm-up.'), findsOneWidget);
      expect(
        find.text('The real thing. Around one in twenty falls.'),
        findsOneWidget,
      );
      expect(
        find.text('Spider games run long — the timer is optional.'),
        findsOneWidget,
      );
      expect(
        find.text('Relaxed lets you deal a row with a column empty.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Suits in play, Two suits, spades and hearts. The standard game.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Winnable'), findsNothing);
      expect(find.byKey(const Key('ssetup-deal-winnable')), findsNothing);
      expect(find.byKey(const Key('ssetup-keep')), findsNothing);
    },
  );

  testWidgets('defaults come from the last Spider game', (tester) async {
    final store = AppStore.memory();
    await store.write(StoreDoc.settings, {
      'lastSpiderOptions': {'suits': 'four', 'timed': false, 'relaxed': true},
    });
    await openScreen(tester, const NewSpiderScreen(), store: store);
    expect(selected(tester, 'ssetup-suits-four'), isTrue);
    expect(selected(tester, 'ssetup-timed-off'), isTrue);
    expect(selected(tester, 'ssetup-rule-relaxed'), isTrue);
  });

  testWidgets(
    'each choice changes the dealt game; Deal writes the last options and opens the board',
    (tester) async {
      final scope = await openScreen(tester, const NewSpiderScreen());
      await tapKey(tester, 'ssetup-suits-one');
      await tapKey(tester, 'ssetup-timed-off');
      await tapKey(tester, 'ssetup-rule-relaxed');
      await tapKey(tester, 'ssetup-deal');
      await settle(tester, transition: true);
      final game = scope.controller.game as SpiderGame;
      expect(game.options.suits, SpiderSuits.one);
      expect(game.options.timed, isFalse);
      expect(game.options.relaxed, isTrue);
      expect(game.dealNumber.value, 42);
      expect(find.byType(NewSpiderScreen), findsNothing);
      expect(find.byType(BoardView), findsOneWidget);
      expect(find.text('Spider · 1 suit'), findsOneWidget);
      expect(scope.settingsStore.lastSpiderOptions.suits, SpiderSuits.one);
      expect(scope.settingsStore.lastSpiderOptions.relaxed, isTrue);
      expect(
        scope.stats.document.klondike.total.played,
        0,
        reason: 'the Klondike had no move and is another type anyway',
      );
    },
  );

  testWidgets('Keep playing wears the screen\'s violet accent (#154)', (
    tester,
  ) async {
    final scope = await openScreen(tester, const NewSpiderScreen());
    scope.controller.replaceGame(SpiderGame.deal(DealNumber(9)));
    drawFromStock(scope);
    await settle(tester);
    final c = keepPlayingColours(tester, 'ssetup-keep');
    expect(
      c.border,
      SetupAccent.violet.border,
      reason: 'outlined in the accent, not grey',
    );
    expect(
      c.text,
      SetupAccent.violet.text,
      reason: 'labelled in the accent, not grey',
    );
  });

  testWidgets(
    'dealing over an unfinished Spider with a move records one loss',
    (tester) async {
      final scope = await openScreen(tester, const NewSpiderScreen());
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(9)));
      drawFromStock(scope);
      await settle(tester);
      expect(find.byKey(const Key('ssetup-keep')), findsOneWidget);
      await tapKey(tester, 'ssetup-deal');
      await settle(tester, transition: true);
      await scope.statsListener.lastRecord;
      expect(scope.stats.document.spider.total.played, 1);
      expect(scope.stats.document.spider.total.won, 0);
      expect(scope.controller.game.dealNumber.value, 42);
    },
  );

  testWidgets(
    'Keep playing appears only with a Spider with moves and resumes it',
    (tester) async {
      final scope = await openScreen(tester, const NewSpiderScreen());
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(9)));
      await settle(tester);
      expect(
        find.byKey(const Key('ssetup-keep')),
        findsNothing,
        reason: 'no move yet',
      );
      drawFromStock(scope);
      scope.controller.pause();
      await settle(tester);
      await tapKey(tester, 'ssetup-keep');
      await settle(tester, transition: true);
      expect(find.byType(NewSpiderScreen), findsNothing);
      expect(scope.controller.game.dealNumber.value, 9);
      expect(scope.controller.isPaused, isFalse);
      expect(scope.stats.document.spider.total.played, 0);
    },
  );
}
