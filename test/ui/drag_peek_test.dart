import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_pointer.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
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

Duration _clock = Duration.zero;

/// The exposed band at the top of a card.
Offset bandOf(WidgetTester tester, String key) {
  final rect = tester.getRect(find.byKey(Key(key)));
  return Offset(rect.center.dx, rect.top + 3);
}

Future<TestGesture> pressAt(WidgetTester tester, Offset point) async {
  _clock += const Duration(milliseconds: 500);
  final gesture = await tester.createGesture();
  await gesture.down(point, timeStamp: _clock);
  await tester.pump();
  return gesture;
}

Future<void> moveTo(
  WidgetTester tester,
  TestGesture gesture,
  Offset point,
) async {
  _clock += const Duration(milliseconds: 16);
  await gesture.moveTo(point, timeStamp: _clock);
  await tester.pump();
}

Future<void> release(WidgetTester tester, TestGesture gesture) async {
  _clock += const Duration(milliseconds: 16);
  await gesture.up(timeStamp: _clock);
  await tester.pump();
}

/// Drags from [from] to [to] with an intermediate step that crosses the slop.
Future<void> dragTo(WidgetTester tester, Offset from, Offset to) async {
  final g = await pressAt(tester, from);
  await moveTo(tester, g, from + const Offset(0, 20));
  await moveTo(tester, g, to);
  await release(tester, g);
}

KlondikeGame gameOf(GameController c) => c.game as KlondikeGame;

Future<void> settle(WidgetTester tester) =>
    tester.pump(springBackDuration + const Duration(milliseconds: 50));

void main() {
  final position = klondike(
    tableau: [cards('8H* 7S 6D'), cards('8D'), cards('7D'), [], [], [], []],
    waste: cards('AH'),
  );

  testWidgets('a drag to a legal target applies exactly one move', (
    tester,
  ) async {
    final controller = controllerFor(position);
    await pumpBoard(tester, controller);
    final from = bandOf(tester, 'card-t0-1');
    final to = tester.getCenter(find.byKey(const Key('card-t1-0')));
    final g = await pressAt(tester, from);
    await moveTo(tester, g, from + const Offset(0, 20));
    expect(controller.dragging, isNotNull);
    expect(controller.dragging!.pile, const TableauPile(0));
    expect(controller.dragging!.start, 1);
    expect(controller.dragging!.cards, cards('7S 6D'));
    expect(controller.selection, isNull);
    // The lifted run follows the finger, keeping the grab offset.
    final lifted = tester.getRect(find.byKey(const Key('card-t0-1')));
    expect(
      lifted.top,
      closeTo(
        tester.getRect(find.byKey(const Key('card-t0-0'))).top + 6 + 20,
        0.5,
      ),
    );
    expect(
      tester.widget<PlayingCard>(find.byKey(const Key('card-t0-1'))).lifted,
      isTrue,
    );
    // Accepting piles outline teal: only column 1 takes a 7♠.
    expect(find.byKey(const Key('target-t1')), findsOneWidget);
    expect(find.byKey(const Key('target-t2')), findsNothing);
    await moveTo(tester, g, to);
    await release(tester, g);
    expect(gameOf(controller).tableau[1], cards('8D 7S 6D'));
    expect(gameOf(controller).tableau[0], cards('8H'));
    expect(gameOf(controller).moves, 1);
    expect(controller.dragging, isNull);
    expect(controller.springBack, isNull);
    expect(find.byKey(const Key('target-t1')), findsNothing);
  });

  testWidgets(
    'an illegal drop, a felt drop and a drop on its own column spring back',
    (tester) async {
      // The spring-back travels only with animations on (#99).
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      final home = tester.getRect(find.byKey(const Key('card-t0-1')));
      final from = bandOf(tester, 'card-t0-1');
      for (final target in [
        tester.getCenter(
          find.byKey(const Key('card-t2-0')),
        ), // 7♠ on 7♦: illegal
        const Offset(200, 48 + 72 + 6), // felt between the rows
        from + const Offset(0, 40), // its own column
      ]) {
        await dragTo(tester, from, target);
        expect(gameOf(controller), position);
        expect(controller.springBack, isNotNull, reason: '$target');
        expect(controller.dragging, isNull);
        // Halfway through the spring-back the run is between the drop and home.
        await tester.pump(const Duration(milliseconds: 100));
        final mid = tester.getRect(find.byKey(const Key('card-t0-1')));
        expect(mid, isNot(home), reason: 'still travelling from $target');
        await settle(tester);
        expect(controller.springBack, isNull);
        expect(tester.getRect(find.byKey(const Key('card-t0-1'))), home);
        expect(
          tester.widget<PlayingCard>(find.byKey(const Key('card-t0-1'))).lifted,
          isFalse,
        );
      }
      expect(gameOf(controller).moves, 0);
    },
  );

  testWidgets(
    'a drop on another suit\'s foundation goes to the card\'s own foundation',
    (tester) async {
      final aces = klondike(
        tableau: [cards('AS'), cards('KH'), [], [], [], [], []],
      );
      final controller = controllerFor(aces);
      await pumpBoard(tester, controller);
      await dragTo(
        tester,
        bandOf(tester, 'card-t0-0'),
        tester.getCenter(find.byKey(const Key('slot-f-hearts'))),
      );
      expect(gameOf(controller).foundations[Suit.spades.index], cards('AS'));
      expect(gameOf(controller).foundations[Suit.hearts.index], isEmpty);
    },
  );

  testWidgets(
    'the draw-3 waste drags only its top card, from its fanned position',
    (tester) async {
      final controller = controllerFor(
        applied(
          KlondikeGame.deal(
            DealNumber(7),
            const KlondikeOptions(draw: DrawMode.three),
          ),
          const Draw(),
        ),
      );
      await pumpBoard(tester, controller);
      final middle = tester.getRect(find.byKey(const Key('card-waste-1')));
      var g = await pressAt(tester, Offset(middle.left + 3, middle.center.dy));
      await moveTo(tester, g, Offset(middle.left + 3, middle.center.dy + 30));
      expect(controller.dragging, isNull, reason: 'not the top card');
      await release(tester, g);
      final top = tester.getRect(find.byKey(const Key('card-waste-2')));
      g = await pressAt(tester, Offset(top.right - 3, top.center.dy));
      await moveTo(tester, g, Offset(top.right - 3, top.center.dy + 30));
      expect(controller.dragging, isNotNull);
      expect(controller.dragging!.pile, const WastePile());
      expect(controller.dragging!.homeRects.single, top);
      await release(tester, g);
      await settle(tester);
    },
  );

  group('peek', () {
    // Three face-down cards under thirty-two face-up ones: compressed by
    // just under the layout's 4-point margin, so a peek reaches full spacing.
    final tall = klondike(
      tableau: [
        [
          for (var i = 0; i < 3; i++) standardDeck()[i],
          for (var i = 3; i < 35; i++) standardDeck()[i].up,
        ],
        [],
        [],
        [],
        [],
        [],
        [],
      ],
    );

    testWidgets(
      'a long press fans the face-up cards to full spacing and restores them on release',
      (tester) async {
        final controller = controllerFor(tall);
        await pumpBoard(tester, controller);
        double offset() =>
            tester.getRect(find.byKey(const Key('card-t0-10'))).top -
            tester.getRect(find.byKey(const Key('card-t0-9'))).top;
        final compressed = offset();
        expect(compressed, lessThan(17));
        final g = await pressAt(tester, bandOf(tester, 'card-t0-34'));
        await tester.pump(peekDelay + const Duration(milliseconds: 50));
        expect(controller.peekColumn, 0);
        expect(offset(), closeTo(17, 0.01), reason: 'full spacing');
        expect(
          tester.getRect(find.byKey(const Key('card-t0-34'))).bottom,
          lessThanOrEqualTo(844 - 92 + 0.01),
        );
        for (var i = 0; i < 3; i++) {
          expect(
            tester
                .widget<PlayingCard>(find.byKey(Key('card-t0-$i')))
                .card!
                .faceUp,
            isFalse,
          );
        }
        expect(gameOf(controller), tall);
        await release(tester, g);
        expect(controller.peekColumn, isNull);
        expect(offset(), closeTo(compressed, 0.01));
        expect(gameOf(controller), tall);
        expect(gameOf(controller).moves, 0);
        expect(controller.selection, isNull, reason: 'a peek is not a tap');
      },
    );

    testWidgets(
      'moving after a long press turns the peek into a drag of the pressed card',
      (tester) async {
        final controller = controllerFor(position);
        await pumpBoard(tester, controller);
        final from = bandOf(tester, 'card-t0-1');
        final g = await pressAt(tester, from);
        await tester.pump(peekDelay + const Duration(milliseconds: 50));
        expect(controller.peekColumn, 0);
        await moveTo(tester, g, from + const Offset(0, 20));
        expect(controller.peekColumn, isNull);
        expect(controller.dragging?.start, 1);
        await moveTo(
          tester,
          g,
          tester.getCenter(find.byKey(const Key('card-t1-0'))),
        );
        await release(tester, g);
        expect(gameOf(controller).tableau[1], cards('8D 7S 6D'));
      },
    );

    testWidgets('a press on a face-down card peeks but never drags', (
      tester,
    ) async {
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      final from = bandOf(tester, 'card-t0-0');
      final g = await pressAt(tester, from);
      await tester.pump(peekDelay + const Duration(milliseconds: 50));
      expect(controller.peekColumn, 0);
      await moveTo(tester, g, from + const Offset(0, 30));
      expect(controller.dragging, isNull);
      await release(tester, g);
      expect(gameOf(controller), position);
      expect(controller.selection, isNull);
    });

    testWidgets('a column with no face-up card does not peek', (tester) async {
      final controller = controllerFor(
        klondike(tableau: [cards('KS'), [], [], [], [], [], []], dump: 1),
      );
      await pumpBoard(tester, controller);
      final g = await pressAt(tester, bandOf(tester, 'card-t1-40'));
      await tester.pump(peekDelay + const Duration(milliseconds: 50));
      expect(controller.peekColumn, isNull);
      await release(tester, g);
    });
  });
}
