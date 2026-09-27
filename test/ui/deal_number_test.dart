import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/screens/deal_number_field.dart';
import 'package:honest_solitaire/ui/screens/loading_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/widgets/option_panel.dart';

import 'setup_helpers.dart';

Future<void> type(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.byKey(const Key('deal-number-field')));
  await tester.enterText(find.byKey(const Key('deal-number-field')), text);
  await settle(tester);
}

String fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('deal-number-field')))
    .controller!
    .text;

bool dealEnabled(WidgetTester tester, String key) =>
    tester.widget<DealButton>(find.byKey(Key(key))).enabled;

void main() {
  test('parseDealNumber: blank, valid, invalid; leading zeros ignored', () {
    expect(parseDealNumber(''), isA<Blank>());
    expect((parseDealNumber('48213') as Valid).number.value, 48213);
    expect((parseDealNumber('0048213') as Valid).number.value, 48213);
    expect((parseDealNumber('999999') as Valid).number.value, 999999);
    expect(parseDealNumber('0'), isA<Invalid>());
    expect(parseDealNumber('000'), isA<Invalid>());
    expect(parseDealNumber('1000000'), isA<Invalid>());
  });

  testWidgets(
    'blank deals randomly; 48213 deals that deal exactly, for Klondike',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      expect(fieldText(tester), '', reason: 'blank on every visit');
      await type(tester, '48213');
      expect(find.byKey(const Key('deal-number-error')), findsNothing);
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      final game = scope.controller.game as KlondikeGame;
      expect(game.dealNumber.value, 48213);
      expect(
        game,
        KlondikeGame.deal(DealNumber(48213), game.options),
        reason: 'the same number and options give the same deal',
      );
      expect(game.winnable, isFalse);
    },
  );

  testWidgets(
    '48213 deals that deal exactly for Spider; a typed number equal to the current deal is allowed',
    (tester) async {
      final scope = await openScreen(
        tester,
        const NewSpiderScreen(),
        numbers: [7],
      );
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(48213)));
      await settle(tester);
      await type(tester, '48213');
      await tapKey(tester, 'ssetup-deal');
      await settle(tester, transition: true);
      final game = scope.controller.game as SpiderGame;
      expect(
        game.dealNumber.value,
        48213,
        reason: 'a retry, exempt from the reroll',
      );
      expect(game, SpiderGame.deal(DealNumber(48213), game.options));
    },
  );

  testWidgets(
    'a number forces Random and shows why; clearing restores Winnable only; the forced choice is never saved',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      await tapKey(tester, 'ksetup-deal-winnable');
      await type(tester, '12');
      ChoiceButton winnable() => tester.widget<ChoiceButton>(
        find.byKey(const Key('ksetup-deal-winnable')),
      );
      expect(winnable().selected, isFalse);
      expect(winnable().enabled, isFalse);
      expect(
        tester
            .widget<ChoiceButton>(find.byKey(const Key('ksetup-deal-random')))
            .selected,
        isTrue,
      );
      expect(find.byKey(const Key('deal-number-reason')), findsOneWidget);
      expect(
        find.text("A chosen deal can't be promised winnable"),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ksetup-deal-description')), findsNothing);
      // Tapping the disabled choice does nothing.
      await tapKey(tester, 'ksetup-deal-winnable');
      expect(winnable().selected, isFalse);
      // Clearing with the ✕ restores the previous choice.
      await tapKey(tester, 'deal-number-clear');
      expect(fieldText(tester), '');
      expect(winnable().selected, isTrue);
      expect(winnable().enabled, isTrue);
      expect(find.byKey(const Key('deal-number-reason')), findsNothing);
      // With a number, Deal is exact and goes nowhere near the search.
      await type(tester, '12');
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect(find.byType(LoadingScreen), findsNothing);
      expect(scope.controller.game.dealNumber.value, 12);
      expect(
        scope.playSettings.value.winnableOnly,
        isFalse,
        reason: 'Settings untouched',
      );
    },
  );

  testWidgets(
    '0 and 1000000 disable Deal and show the error live; letters are dropped',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      await type(tester, '0');
      expect(find.byKey(const Key('deal-number-error')), findsOneWidget);
      expect(find.text('Enter 1 to 999999'), findsOneWidget);
      expect(dealEnabled(tester, 'ksetup-deal'), isFalse);
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect(
        find.byType(NewKlondikeScreen),
        findsOneWidget,
        reason: 'nothing dealt',
      );
      await type(tester, '1000000');
      expect(find.byKey(const Key('deal-number-error')), findsOneWidget);
      expect(dealEnabled(tester, 'ksetup-deal'), isFalse);
      await type(tester, '000');
      expect(find.byKey(const Key('deal-number-error')), findsOneWidget);
      await type(tester, 'abc');
      expect(fieldText(tester), '', reason: 'letters are dropped');
      expect(find.byKey(const Key('deal-number-error')), findsNothing);
      expect(dealEnabled(tester, 'ksetup-deal'), isTrue);
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect(
        scope.controller.game.dealNumber.value,
        42,
        reason: 'blank → random',
      );
    },
  );

  testWidgets(
    'a pasted "Deal #48213" becomes 48213; the cap is seven digits; Spider disables Deal too',
    (tester) async {
      await openScreen(tester, const NewSpiderScreen());
      await type(tester, 'Deal #48213');
      expect(fieldText(tester), '48213');
      await type(tester, '123456789');
      expect(fieldText(tester), '1234567');
      expect(find.byKey(const Key('deal-number-error')), findsOneWidget);
      expect(dealEnabled(tester, 'ssetup-deal'), isFalse);
    },
  );
}
