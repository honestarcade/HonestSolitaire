import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';

GameController controllerFor(Game game, {bool oneTap = false}) =>
    GameController(
      game,
      ValueNotifier(PlaySettings(oneTap: oneTap)),
      ValueNotifier(const DisplayOptions()),
    );

Future<void> pumpBoard(WidgetTester tester, GameController controller) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DisposingHost(
        controller: controller,
        child: BoardView(controller: controller),
      ),
    ),
  );
}

Duration _clock = Duration.zero;

Future<void> tapPoint(
  WidgetTester tester,
  Offset point, {
  Duration advance = const Duration(milliseconds: 500),
}) async {
  _clock += advance;
  final gesture = await tester.createGesture();
  await gesture.down(point, timeStamp: _clock);
  await gesture.up(timeStamp: _clock);
  await tester.pump();
}

Future<void> tapCard(
  WidgetTester tester,
  String key, {
  Duration advance = const Duration(milliseconds: 500),
}) async {
  final rect = tester.getRect(find.byKey(Key(key)));
  await tapPoint(
    tester,
    Offset(rect.center.dx, rect.top + 3),
    advance: advance,
  );
}

Future<void> tapStock(
  WidgetTester tester, {
  Duration advance = const Duration(milliseconds: 500),
}) async {
  final finder = find.byKey(const Key('stock-sliver-0'));
  final rect = finder.evaluate().isEmpty
      ? tester.getRect(find.byKey(const Key('stock-empty')))
      : tester.getRect(finder);
  await tapPoint(tester, rect.center, advance: advance);
}

SpiderGame gameOf(GameController c) => c.game as SpiderGame;

Future<void> drain(WidgetTester tester) =>
    tester.pump(shakeDuration + const Duration(milliseconds: 20));

void main() {
  for (final (deal, suits) in [
    (11, SpiderSuits.one),
    (12, SpiderSuits.two),
    (13, SpiderSuits.four),
  ]) {
    testWidgets(
      '${suits.count} suit(s): the stock shows five slivers, one fewer per deal',
      (tester) async {
        final controller = controllerFor(
          SpiderGame.deal(DealNumber(deal), SpiderOptions(suits: suits)),
        );
        await pumpBoard(tester, controller);
        expect(find.byKey(const Key('stock-sliver-4')), findsOneWidget);
        expect(find.byKey(const Key('stock-empty')), findsNothing);
        expect(find.bySemanticsLabel('Stock, 5 deals left'), findsOneWidget);
        for (var dealt = 1; dealt <= 5; dealt++) {
          await tapStock(tester);
          expect(gameOf(controller).rowsLeft, 5 - dealt);
          expect(find.byKey(Key('stock-sliver-${5 - dealt}')), findsNothing);
          if (dealt < 5) {
            expect(
              find.byKey(Key('stock-sliver-${4 - dealt}')),
              findsOneWidget,
            );
          }
        }
        expect(find.byKey(const Key('stock-empty')), findsOneWidget);
        expect(find.text('EMPTY'), findsOneWidget);
        expect(find.bySemanticsLabel('Stock, no deals left'), findsOneWidget);
        // Tapping EMPTY shakes the stock and changes nothing.
        final before = gameOf(controller);
        await tapStock(tester);
        expect(gameOf(controller), before);
        expect(controller.shake?.pile, const StockPile());
        await drain(tester);
      },
    );
  }

  testWidgets(
    'a strict deal with an empty column shakes the stock and changes nothing',
    (tester) async {
      final position = spider(
        tableau: [
          cards('7H'),
          [],
          cards('KS'),
          cards('KS'),
          cards('KS'),
          cards('KS'),
          cards('KH'),
          cards('KH'),
          cards('KH'),
          cards('KH'),
        ],
        stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-0');
      expect(controller.selection, (const TableauPile(0), 0));
      await tapStock(tester);
      expect(gameOf(controller), position);
      expect(controller.shake?.pile, const StockPile());
      expect(
        controller.selection,
        isNull,
        reason: 'a refused deal clears the selection',
      );
      expect(controller.currentHint, isNull);
      await drain(tester);
    },
  );

  testWidgets('a second stock tap within 300 ms of a deal is ignored', (
    tester,
  ) async {
    final controller = controllerFor(
      SpiderGame.deal(
        DealNumber(12),
        const SpiderOptions(suits: SpiderSuits.two),
      ),
    );
    await pumpBoard(tester, controller);
    await tapStock(tester);
    expect(gameOf(controller).rowsLeft, 4);
    await tapStock(tester, advance: const Duration(milliseconds: 150));
    expect(gameOf(controller).rowsLeft, 4, reason: 'too soon');
    expect(controller.shake, isNull, reason: 'ignored, not refused');
    await tapStock(tester, advance: const Duration(milliseconds: 400));
    expect(gameOf(controller).rowsLeft, 3);
  });

  testWidgets(
    'a mixed-suit tap selects only the same-suit run above it, and one-tap moves that run',
    (tester) async {
      final position = spider(
        tableau: [
          cards('9H 8S 7S'),
          cards('8H'),
          cards('10S'),
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-0');
      expect(controller.selection, (
        const TableauPile(0),
        1,
      ), reason: '9♥ is not part of the ♠ run');
      expect(
        tester.widget<PlayingCard>(find.byKey(const Key('card-t0-1'))).ring,
        CardRing.selected,
      );
      expect(
        tester.widget<PlayingCard>(find.byKey(const Key('card-t0-0'))).ring,
        CardRing.none,
      );
      // With one-tap on, tapping the 9♥ moves the ♠ run to its best spot (the 10♠? no: 8♠ needs a 9).
      final oneTap = controllerFor(position, oneTap: true);
      await pumpBoard(tester, oneTap);
      await tapCard(tester, 'card-t0-1');
      // 8♠ 7♠ onto 9♥? A same-suit 9 is absent, 9♥ is its own parent; onto an empty column is allowed.
      expect(gameOf(oneTap).tableau[0], cards('9H'));
      expect(gameOf(oneTap).tableau[3], cards('8S 7S'));
    },
  );

  testWidgets(
    'select then a legal target moves a run; an illegal target shakes',
    (tester) async {
      final position = spider(
        tableau: [
          cards('7S 6S'),
          cards('8S'),
          cards('9H'),
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-0');
      await tapCard(tester, 'card-t2-0');
      expect(gameOf(controller), position, reason: '7 does not go on 9');
      // 9♥ is selectable, so the selection switched to it.
      expect(controller.selection, (const TableauPile(2), 0));
      await tapCard(tester, 'card-t0-0');
      expect(controller.selection, (
        const TableauPile(0),
        0,
      ), reason: '9♥ cannot land on 7♠; 7♠ is selectable → switch');
      await tapCard(tester, 'card-t1-0');
      expect(gameOf(controller).tableau[1], cards('8S 7S 6S'));
      expect(controller.selection, isNull);
    },
  );

  testWidgets('a double tap sends the whole same-suit run to its best column', (
    tester,
  ) async {
    final position = spider(
      tableau: [
        cards('KH* 7S 6S'),
        cards('8S'),
        cards('8H'),
        [],
        [],
        [],
        [],
        [],
        [],
        [],
      ],
      options: const SpiderOptions(suits: SpiderSuits.two),
    );
    final controller = controllerFor(position);
    await pumpBoard(tester, controller);
    await tapCard(tester, 'card-t0-2');
    expect(controller.selection, (
      const TableauPile(0),
      2,
    ), reason: 'a tap inside the run selects from that card');
    await tapCard(
      tester,
      'card-t0-2',
      advance: const Duration(milliseconds: 100),
    );
    expect(
      gameOf(controller).tableau[1],
      cards('8S 7S 6S'),
      reason: 'the same-suit 8 wins',
    );
    expect(gameOf(controller).tableau[0], cards('KH'), reason: 'auto-flipped');
  });

  testWidgets(
    'a completed run leaves the column and fills the first slot in the same frame',
    (tester) async {
      final position = spider(
        tableau: [
          [c('5H*'), ...kingDown(Suit.spades, 2)],
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
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      expect(find.byKey(const Key('completed-0')), findsNothing);
      expect(find.byKey(const Key('completed-slot-0')), findsOneWidget);
      await tapCard(tester, 'card-t1-0');
      await tapCard(tester, 'card-t0-12');
      expect(gameOf(controller).completed, [Suit.spades]);
      expect(gameOf(controller).tableau[0], cards('5H'));
      expect(find.byKey(const Key('completed-0')), findsOneWidget);
      expect(find.byKey(const Key('completed-slot-0')), findsNothing);
      expect(find.byKey(const Key('card-t0-1')), findsNothing);
      expect(find.bySemanticsLabel('Completed runs, 1 of 8'), findsOneWidget);
      final king = tester.widget<PlayingCard>(
        find.byKey(const Key('completed-0')),
      );
      expect(king.card, const Card(13, Suit.spades, faceUp: true));
      expect(king.narrow, isTrue);
    },
  );
}
