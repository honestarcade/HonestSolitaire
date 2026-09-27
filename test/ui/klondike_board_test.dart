import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/board/slot_painter.dart';
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

/// A monotonic pointer clock: test gestures carry zero timestamps unless
/// given one, and the double-tap window reads them.
Duration _clock = Duration.zero;

/// Taps [point] [advance] after the previous tap.
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

/// Taps the exposed band at the top of a card (the part a covering card
/// leaves visible).
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

KlondikeGame gameOf(GameController c) => c.game as KlondikeGame;

CardRing ringOf(WidgetTester tester, String key) =>
    tester.widget<PlayingCard>(find.byKey(Key(key))).ring;

void main() {
  testWidgets('tapping the stock draws three; an empty stock recycles', (
    tester,
  ) async {
    final controller = controllerFor(
      KlondikeGame.deal(
        DealNumber(7),
        const KlondikeOptions(draw: DrawMode.three),
      ),
    );
    await pumpBoard(tester, controller);
    await tapCard(tester, 'card-stock-23');
    expect(gameOf(controller).waste, hasLength(3));
    expect(gameOf(controller).moves, 1);
    final empty = klondike(
      tableau: [cards('KS'), [], [], [], [], [], []],
      waste: cards('2H 3H'),
    );
    controller.replaceGame(empty);
    await tester.pump();
    await tapPoint(
      tester,
      tester.getCenter(find.byKey(const Key('slot-stock'))),
    );
    expect(gameOf(controller).stock, hasLength(2));
    expect(gameOf(controller).waste, isEmpty);
    // Empty stock and empty waste: the stock shakes, nothing changes.
    final nothing = klondike(tableau: [cards('KS'), [], [], [], [], [], []]);
    controller.replaceGame(nothing);
    await tester.pump();
    await tapPoint(
      tester,
      tester.getCenter(find.byKey(const Key('slot-stock'))),
    );
    expect(controller.shake?.pile, const StockPile());
    expect(gameOf(controller), nothing);
    await tester.pump(shakeDuration + const Duration(milliseconds: 20));
  });

  testWidgets(
    'select a run, then a legal target: the run moves and rings while selected',
    (tester) async {
      final position = klondike(
        tableau: [cards('8H* 7S 6D'), cards('8D'), cards('7D'), [], [], [], []],
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-1');
      expect(controller.selection, (const TableauPile(0), 1));
      expect(ringOf(tester, 'card-t0-1'), CardRing.selected);
      expect(ringOf(tester, 'card-t0-2'), CardRing.selected);
      expect(ringOf(tester, 'card-t0-0'), CardRing.none);
      // Empty columns show the teal outline while a selection is active.
      final outline =
          tester.widget<CustomPaint>(find.byKey(const Key('slot-t3'))).painter
              as SlotPainter;
      expect(outline.edgeColor, const Color(0x8000D6B4));
      await tapCard(tester, 'card-t1-0');
      expect(controller.selection, isNull);
      expect(gameOf(controller).tableau[1], cards('8D 7S 6D'));
      expect(gameOf(controller).tableau[0], cards('8H'));
      expect(gameOf(controller).moves, 1);
      final quiet =
          tester.widget<CustomPaint>(find.byKey(const Key('slot-t3'))).painter
              as SlotPainter;
      expect(quiet.edgeColor, isNot(const Color(0x8000D6B4)));
    },
  );

  testWidgets(
    'select, then an illegal target: a shake, no change, selection cleared',
    (tester) async {
      final position = klondike(
        tableau: [cards('8H* 7S 6D'), cards('8D'), cards('7D'), [], [], [], []],
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-1');
      await tapCard(
        tester,
        'card-t2-0',
      ); // 7♠ onto 7♦: rank mismatch, and 7♦ is selectable
      expect(gameOf(controller), position);
      // The tapped card was itself selectable, so the selection switched to it.
      expect(controller.selection, (const TableauPile(2), 0));
      // Now an illegal target that is not selectable: the empty column needs a king.
      await tapCard(
        tester,
        'card-t0-2',
      ); // 6♦ selected? No: 7♦ → 6♦ is legal? 7♦ onto 6♦: no. Refused.
      await tester.pump();
      // 7♦ cannot go on 6♦ (needs a black 8), 6♦ is a selectable run start → switched.
      expect(controller.selection, (const TableauPile(0), 2));
      await tapPoint(
        tester,
        tester.getCenter(find.byKey(const Key('slot-t4'))),
      );
      expect(
        gameOf(controller),
        position,
        reason: 'a 6 does not go on an empty column',
      );
      expect(controller.selection, isNull);
      expect(controller.shake, isNotNull);
      expect(controller.shake!.pile, const TableauPile(0));
      expect(controller.shake!.start, 2);
      await tester.pump(shakeDuration + const Duration(milliseconds: 20));
      expect(controller.shake, isNull, reason: 'the shake clears itself');
      expect(gameOf(controller), position);
    },
  );

  testWidgets('tapping the felt or the selected card clears the selection', (
    tester,
  ) async {
    final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
    await pumpBoard(tester, controller);
    await tapCard(tester, 'card-t2-2');
    expect(controller.selection, (const TableauPile(2), 2));
    await tapPoint(tester, const Offset(200, 48 + 72 + 6));
    expect(controller.selection, isNull);
    await tapCard(tester, 'card-t2-2');
    await tapCard(tester, 'card-t2-2');
    expect(
      controller.selection,
      isNull,
      reason: 're-tapping the selected card clears it',
    );
  });

  testWidgets(
    'one-tap moves a card to its best destination, or selects it when there is none',
    (tester) async {
      final position = klondike(
        tableau: [cards('8H* 7S 6D'), cards('8D'), cards('KC'), [], [], [], []],
        waste: cards('AH'),
      );
      final controller = controllerFor(position, oneTap: true);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-1');
      expect(gameOf(controller).tableau[1], cards('8D 7S 6D'));
      expect(controller.selection, isNull);
      await tapCard(tester, 'card-waste-0');
      expect(gameOf(controller).foundations[Suit.hearts.index], cards('AH'));
      await tapCard(tester, 'card-t2-0');
      expect(controller.selection, (
        const TableauPile(2),
        0,
      ), reason: 'the king has no destination');
      expect(gameOf(controller).moves, 2);
    },
  );

  testWidgets(
    'a double tap sends an ace to its foundation without delaying the first tap',
    (tester) async {
      final position = klondike(
        tableau: [cards('8H* 7S 6D'), cards('AS'), [], [], [], [], []],
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t1-0');
      expect(controller.selection, (
        const TableauPile(1),
        0,
      ), reason: 'the first tap acts at once');
      await tapCard(
        tester,
        'card-t1-0',
        advance: const Duration(milliseconds: 120),
      );
      expect(gameOf(controller).foundations[Suit.spades.index], cards('AS'));
      expect(gameOf(controller).tableau[1], isEmpty);
      expect(controller.selection, isNull);
      // A second tap after the window is a plain tap: it clears the selection.
      controller.replaceGame(position);
      await tester.pump();
      await tapCard(tester, 'card-t1-0');
      await tapCard(tester, 'card-t1-0');
      expect(gameOf(controller), position);
      expect(controller.selection, isNull);
    },
  );

  testWidgets('a foundation card is selected, never one-tapped away', (
    tester,
  ) async {
    final position = klondike(
      tableau: [cards('3H'), [], [], [], [], [], []],
      foundations: [cards('AS 2S'), [], [], []],
    );
    final controller = controllerFor(position, oneTap: true);
    await pumpBoard(tester, controller);
    await tapCard(tester, 'card-f-spades-1');
    expect(gameOf(controller), position);
    expect(controller.selection, (const FoundationPile(Suit.spades), 1));
    // Select-then-tap does move it.
    await tapCard(tester, 'card-t0-0');
    expect(gameOf(controller).tableau[0], cards('3H 2S'));
  });

  testWidgets(
    'taps on face-down cards or broken runs do nothing; auto-flip off flips a top',
    (tester) async {
      final position = klondike(
        tableau: [
          cards('8H* 7S 6D'),
          cards('KC*'),
          cards('9S 4D'),
          [],
          [],
          [],
          [],
        ],
        options: const KlondikeOptions(autoFlip: false),
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await tapCard(tester, 'card-t0-0');
      expect(controller.selection, isNull);
      await tapCard(tester, 'card-t2-0');
      expect(
        controller.selection,
        isNull,
        reason: '9♠ under 4♦ is not a run start',
      );
      await tapCard(tester, 'card-t1-0');
      expect(gameOf(controller).tableau[1], cards('KC'));
      expect(gameOf(controller).moves, 1);
    },
  );

  testWidgets('any tap clears a showing hint; taps are ignored once won', (
    tester,
  ) async {
    final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
    await pumpBoard(tester, controller);
    final won = klondike(
      tableau: [cards('KC'), [], [], [], [], [], []],
      foundations: [
        suitRun(Suit.spades, 13),
        suitRun(Suit.hearts, 13),
        suitRun(Suit.diamonds, 13),
        suitRun(Suit.clubs, 12),
      ],
    );
    final finished = applied(won, const TableauToFoundation(0));
    controller.replaceGame(finished);
    await tester.pump();
    await tapPoint(
      tester,
      tester.getCenter(find.byKey(const Key('slot-stock'))),
    );
    expect(controller.selection, isNull);
    expect(controller.shake, isNull);
  });

  testWidgets('piles carry tap semantics', (tester) async {
    final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
    await pumpBoard(tester, controller);
    expect(find.bySemanticsLabel('Stock, 24 cards'), findsOneWidget);
    expect(find.bySemanticsLabel('Spades foundation, empty'), findsOneWidget);
    expect(find.bySemanticsLabel('Waste, empty'), findsOneWidget);
    final position = klondike(
      tableau: [cards('KS'), [], [], [], [], [], []],
      waste: cards('2H'),
    );
    controller.replaceGame(position);
    await tester.pump();
    expect(
      find.bySemanticsLabel('Stock, empty, double-tap to recycle'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Column 2, empty'), findsOneWidget);
  });
}
