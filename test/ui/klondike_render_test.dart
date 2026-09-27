import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/board/slot_painter.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';

GameController controllerFor(Game game) => GameController(
  game,
  ValueNotifier(const PlaySettings(oneTap: false)),
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

/// Every keyed card on the board, compared with the engine's piles.
void expectBoardMatches(WidgetTester tester, KlondikeGame game) {
  final piles = <BoardPile, List<Card>>{
    for (var c = 0; c < 7; c++) TableauPile(c): game.tableau[c],
    const StockPile(): game.stock,
    const WastePile(): game.waste,
    for (final s in Suit.values) FoundationPile(s): game.foundations[s.index],
  };
  var count = 0;
  for (final entry in piles.entries) {
    for (var i = 0; i < entry.value.length; i++) {
      final finder = find.byKey(
        Key('card-${entry.key.token}-$i'),
        skipOffstage: false,
      );
      expect(finder, findsOneWidget, reason: '${entry.key.token}[$i]');
      final widget = tester.widget<PlayingCard>(finder);
      expect(widget.card, entry.value[i], reason: '${entry.key.token}[$i]');
      count++;
    }
  }
  expect(count, 52);
  expect(find.byType(PlayingCard, skipOffstage: false), findsNWidgets(52));
}

void main() {
  testWidgets('a fixed deal renders 52 keyed cards matching the engine', (
    tester,
  ) async {
    final game = KlondikeGame.deal(
      DealNumber(7),
      const KlondikeOptions(draw: DrawMode.three),
    );
    final controller = controllerFor(game);
    await pumpBoard(tester, controller);
    expectBoardMatches(tester, game);
    // Face states too: column tops are up, the rest down.
    final top = tester.widget<PlayingCard>(find.byKey(const Key('card-t6-6')));
    expect(top.card!.faceUp, isTrue);
    final under = tester.widget<PlayingCard>(
      find.byKey(const Key('card-t6-5'), skipOffstage: false),
    );
    expect(under.card!.faceUp, isFalse);
    // The stock's covered cards are built but hidden.
    expect(
      find.byKey(const Key('card-stock-0'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('card-stock-0')),
      findsNothing,
      reason: 'offstage',
    );
    expect(find.byKey(const Key('card-stock-23')), findsOneWidget);
  });

  testWidgets('after replaceGame the render matches the new position', (
    tester,
  ) async {
    final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
    await pumpBoard(tester, controller);
    final position = klondike(
      tableau: [cards('KS* QD JC'), cards('AS'), [], [], [], [], []],
      waste: cards('2H 3H 4H'),
      foundations: [[], cards('AH'), [], []],
    );
    controller.replaceGame(position);
    await tester.pump();
    expectBoardMatches(tester, position);
    // And again after an engine move.
    final moved = applied(position, const TableauToFoundation(1));
    controller.replaceGame(moved);
    await tester.pump();
    expectBoardMatches(tester, moved);
    expect(find.byKey(const Key('card-f-spades-0')), findsOneWidget);
  });

  testWidgets(
    'empty foundations show their suit; the stock shows ↻ only with a waste',
    (tester) async {
      final position = klondike(
        tableau: [cards('KS'), [], [], [], [], [], []],
        waste: cards('2H'),
        foundations: [[], cards('AH'), [], []],
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      SlotPainter painter(String key) =>
          tester.widget<CustomPaint>(find.byKey(Key(key))).painter
              as SlotPainter;
      expect(painter('slot-f-spades').placeholderSuit, Suit.spades);
      expect(painter('slot-f-spades').fill, isNotNull);
      expect(
        painter('slot-f-hearts').placeholderSuit,
        isNull,
        reason: 'holds the ace',
      );
      expect(painter('slot-f-hearts').fill, isNull);
      expect(
        painter('slot-stock').recycle,
        isTrue,
        reason: 'empty stock, waste has cards',
      );
      expect(painter('slot-stock').fill, isNotNull);
      controller.replaceGame(applied(position, const Recycle()));
      await tester.pump();
      expect(
        painter('slot-stock').recycle,
        isFalse,
        reason: 'the stock has cards again',
      );
      expect(painter('slot-stock').fill, isNull);
      final nothing = klondike(tableau: [cards('KS'), [], [], [], [], [], []]);
      controller.replaceGame(nothing);
      await tester.pump();
      expect(
        painter('slot-stock').recycle,
        isFalse,
        reason: 'empty stock, empty waste',
      );
    },
  );

  testWidgets('the felt and the dashed outlines paint', (tester) async {
    // The helper dumps the other 51 cards face down under column 0.
    final position = klondike(
      tableau: [cards('KS'), [], [], [], [], [], []],
      dump: 0,
    );
    await pumpBoard(tester, controllerFor(position));
    final felt = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((felt.decoration as BoxDecoration).gradient, feltGradient);
    // Stock, waste, four foundations, six empty columns.
    for (final key in [
      'slot-stock',
      'slot-waste',
      'slot-f-spades',
      'slot-f-clubs',
      'slot-t1',
      'slot-t6',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(
      find.byKey(const Key('slot-t0')),
      findsNothing,
      reason: 'a column with cards has no outline',
    );
    final painters = tester.widgetList<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SlotPainter,
      ),
    );
    expect(painters.length, 12);
    expect(
      (tester.widget<CustomPaint>(find.byKey(const Key('slot-t1'))).painter
              as SlotPainter)
          .dashed,
      isTrue,
    );
  });

  testWidgets('cards sit at the layout positions, snapped to device pixels', (
    tester,
  ) async {
    final game = KlondikeGame.deal(DealNumber(7));
    await pumpBoard(tester, controllerFor(game));
    final rect = tester.getRect(find.byKey(const Key('card-t3-3')));
    expect(rect.left, closeTo(12 + 3 * 53, 0.01));
    expect(rect.top, closeTo(48 + 72 + 14 + 3 * 6, 0.01));
    expect(rect.size, const Size(48, 72));
  });

  testWidgets('a Spider game renders its slivers, slots and columns', (
    tester,
  ) async {
    final game = SpiderGame.deal(DealNumber(11));
    await pumpBoard(tester, controllerFor(game));
    expect(find.byKey(const Key('stock-sliver-0')), findsOneWidget);
    expect(find.byKey(const Key('stock-sliver-4')), findsOneWidget);
    expect(find.byKey(const Key('completed-slot-0')), findsOneWidget);
    expect(find.byKey(const Key('card-t0-5')), findsOneWidget);
    expect(
      find.byType(PlayingCard, skipOffstage: false),
      findsNWidgets(54 + 5),
    );
  });
}
