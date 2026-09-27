import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/content/rules_text.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/widgets/game_tabs.dart';

import 'setup_helpers.dart';

Future<void> expectCards(WidgetTester tester, List<RuleCard> cards) async {
  for (final card in cards) {
    final finder = find.byKey(Key('howto-card-${card.slug}'));
    await tester.ensureVisible(finder);
    expect(
      find.descendant(of: finder, matching: find.text(card.tag)),
      findsOneWidget,
      reason: card.tag,
    );
    expect(
      find.descendant(of: finder, matching: find.text(card.body)),
      findsOneWidget,
      reason: card.tag,
    );
  }
}

void main() {
  testWidgets(
    'both tabs render all their cards and the five gestures; the tabs switch instantly',
    (tester) async {
      await openScreen(tester, const HowToPlayScreen());
      expect(find.text('How to play'), findsOneWidget);
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.klondike,
        reason: 'the controller holds a Klondike',
      );
      expect(klondikeRules.map((c) => c.tag), [
        'THE GOAL',
        'THE TABLEAU',
        'THE STOCK',
        'SCORING',
        'RECORDS',
      ]);
      await expectCards(tester, klondikeRules);
      expect(gestures.map((g) => g.name), [
        'TAP',
        'DOUBLE TAP',
        'DRAG',
        'TAP STOCK',
        'LONG PRESS',
      ]);
      for (final g in gestures) {
        await tester.ensureVisible(find.byKey(Key('howto-gesture-${g.slug}')));
        expect(find.text(g.text), findsOneWidget, reason: g.name);
      }
      expect(find.text('MEDALS AND TIMES'), findsNothing);
      await tapKey(tester, 'howto-tab-spider');
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.spider,
      );
      expect(spiderRules.map((c) => c.tag), [
        'THE GOAL',
        'MOVING CARDS',
        'THE DEALS',
        'DIFFICULTY',
        'SCORING',
        'RECORDS',
      ]);
      await expectCards(tester, spiderRules);
      expect(find.byKey(const Key('howto-card-the-tableau')), findsNothing);
    },
  );

  test('the Spider scoring card states 500, and the Klondike one the -15, penalty and Vegas deal', () {
    final spider = spiderRules.singleWhere((c) => c.tag == 'SCORING');
    expect(spider.numbers.map((n) => n.$2), contains(500));
    expect(
      spider.numbers.map((n) => n.$2),
      containsAll([
        SpiderScoring.atDeal,
        SpiderScoring.perMove,
        SpiderScoring.perRun,
      ]),
    );
    final klondike = klondikeRules.singleWhere((c) => c.tag == 'SCORING');
    expect(klondike.numbers.map((n) => n.$2), containsAll([-15, 2, 10, -52]));
    expect(klondike.body, contains('two points every ten seconds'));
    expect(klondike.body, contains('bonus'));
    expect(
      spiderRules.singleWhere((c) => c.tag == 'THE DEALS').body,
      contains('Relaxed'),
    );
    expect(
      spiderRules.singleWhere((c) => c.tag == 'THE DEALS').body,
      contains('Strict'),
    );
  });

  testWidgets(
    'opened with a Spider game it starts on Spider; opened without one it follows the controller',
    (tester) async {
      await openScreen(tester, const HowToPlayScreen(game: GameType.spider));
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.spider,
      );
      expect(find.byKey(const Key('howto-card-moving-cards')), findsOneWidget);
      final scope = await openScreen(tester, const HowToPlayScreen());
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(3)));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester, transition: true);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen()),
          );
      await settle(tester, transition: true);
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.spider,
      );
    },
  );
}
