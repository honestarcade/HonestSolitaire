import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/feedback/feedback_event.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/motion.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';
import 'win_fixtures.dart';

GameController controllerFor(Game game, {bool animations = true}) =>
    GameController(
      game,
      ValueNotifier(PlaySettings(oneTap: false, cardAnimations: animations)),
      ValueNotifier(const DisplayOptions()),
    );

/// The board with animations on unless [reduced] (the phone's switch).
Future<void> pumpBoard(
  WidgetTester tester,
  GameController controller, {
  bool reduced = false,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
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

Rect rectOf(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key)));

bool between(double v, double a, double b) =>
    (v > a && v < b) || (v > b && v < a);

/// Waste QD onto column 0's KC: one slide from the top right to the left.
final wasteToColumn = klondike(
  tableau: [cards('KC'), [], [], [], [], [], []],
  waste: cards('JS QD'),
);

/// Column 0's QD onto column 1's KC uncovers a face-down 5H: slide, then flip.
final uncover = klondike(
  tableau: [cards('5H* QD'), cards('KC'), [], [], [], [], []],
);

int tickers(WidgetTester tester) => tester.binding.transientCallbackCount;

void main() {
  testWidgets('a moved card slides: between at 90 ms, landed at 180 ms', (
    tester,
  ) async {
    final controller = controllerFor(wasteToColumn);
    await pumpBoard(tester, controller);
    final from = rectOf(tester, 'card-waste-1');
    final landed = controller.game;
    controller.move(const WastePile(), 1, const TableauPile(0));
    await tester.pump();
    expect(controller.game, isNot(landed));
    final committed = controller.game;
    expect(
      rectOf(tester, 'card-t0-1').left,
      closeTo(from.left, 0.5),
      reason: 'starts where it was',
    );
    await tester.pump(const Duration(milliseconds: 90));
    final mid = rectOf(tester, 'card-t0-1');
    await tester.pump(const Duration(milliseconds: 90));
    final to = rectOf(tester, 'card-t0-1');
    expect(between(mid.left, from.left, to.left), isTrue, reason: 'mid-slide');
    expect(between(mid.top, from.top, to.top), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(rectOf(tester, 'card-t0-1'), to, reason: 'at rest where it landed');
    expect(to.left, lessThan(from.left));
    expect(tickers(tester), 0);
    expect(
      identical(controller.game, committed),
      isTrue,
      reason: 'presentation only',
    );
  });

  testWidgets('a second move during an animation lands the first instantly', (
    tester,
  ) async {
    final controller = controllerFor(wasteToColumn);
    await pumpBoard(tester, controller);
    controller.move(const WastePile(), 1, const TableauPile(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final midway = rectOf(tester, 'card-t0-1');
    controller.move(const WastePile(), 0, const TableauPile(0));
    await tester.pump();
    final qd = rectOf(tester, 'card-t0-1');
    expect(qd, isNot(midway), reason: 'the first move is landed');
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      rectOf(tester, 'card-t0-1'),
      qd,
      reason: 'it was already at its final place',
    );
    expect(rectOf(tester, 'card-t0-2').top, greaterThan(qd.top));
  });

  for (final (label, animations, reduced) in [
    ('Card animations off', false, false),
    ('the phone asks for no animations', true, true),
  ]) {
    testWidgets('$label: every change is instant and no ticker runs', (
      tester,
    ) async {
      final controller = controllerFor(wasteToColumn, animations: animations);
      await pumpBoard(tester, controller, reduced: reduced);
      controller.move(const WastePile(), 1, const TableauPile(0));
      await tester.pump();
      final now = rectOf(tester, 'card-t0-1');
      expect(tickers(tester), 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rectOf(tester, 'card-t0-1'), now);
      // The shake: refused move, no motion, the refusal still published
      // (the tick is #107's feedback layer's, tested in haptics_test).
      controller.tapPile(const TableauPile(0), 1);
      controller.tapPile(
        const FoundationPile(Suit.spades),
        null,
        at: const Duration(milliseconds: 500),
      );
      await tester.pump();
      expect(controller.shake, isNotNull, reason: 'refused');
      expect(tickers(tester), 0, reason: 'no shake motion');
      expect(controller.feedback.value?.has(FeedbackEvent.refused), isTrue);
      final still = rectOf(tester, 'card-t0-1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(rectOf(tester, 'card-t0-1'), still);
      // The spring-back: a drop on the felt lands home at once.
      final home = rectOf(tester, 'card-t0-1');
      expect(
        controller.beginDrag(const TableauPile(0), 1, [
          rectOf(tester, 'card-t0-0'),
          home,
        ], home.center),
        isTrue,
      );
      controller.updateDrag(home.center + const Offset(80, 120));
      await tester.pump();
      expect(controller.endDrag(null), isFalse);
      await tester.pump();
      expect(
        controller.springBack,
        isNull,
        reason: 'instant, nothing to animate',
      );
      expect(rectOf(tester, 'card-t0-1'), home);
      expect(tickers(tester), 0);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
      '$label: a revealed card is face up at once, no mid-flip frame',
      (tester) async {
        final controller = controllerFor(uncover, animations: animations);
        await pumpBoard(tester, controller, reduced: reduced);
        controller.move(const TableauPile(0), 1, const TableauPile(1));
        await tester.pump();
        expect(
          (controller.game as KlondikeGame).tableau[0].single.faceUp,
          isTrue,
          reason: 'committed at once',
        );
        expect(
          tester
              .widget<PlayingCard>(find.byKey(const Key('card-t0-0')))
              .card!
              .faceUp,
          isTrue,
          reason: 'drawn face up at once, not mid-flip',
        );
        expect(
          find.byKey(const Key('flip-card-t0-0')),
          findsNothing,
          reason: 'no flip animation layer at all',
        );
        expect(tickers(tester), 0);
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester
              .widget<PlayingCard>(find.byKey(const Key('card-t0-0')))
              .card!
              .faceUp,
          isTrue,
        );
      },
    );
  }

  testWidgets('with no animations the finish sweep completes at once', (
    tester,
  ) async {
    final controller = controllerFor(oneMoveFromSolved, animations: false);
    await pumpBoard(tester, controller);
    controller.move(const WastePile(), 0, const TableauPile(3));
    await tester.pump();
    expect(controller.canFinish, isTrue);
    controller.finish();
    await tester.pump();
    expect(controller.finishing, isFalse, reason: 'no stepping');
    expect(controller.game.isWon, isTrue);
    // The win card's 100 ms fade (#105) is the only ticker left.
    await tester.pump(reducedFade);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tickers(tester), 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'a revealed card flips after the slide lands: mid-flip at 75 ms, face up at 150 ms',
    (tester) async {
      final controller = controllerFor(uncover);
      await pumpBoard(tester, controller);
      controller.move(const TableauPile(0), 1, const TableauPile(1));
      await tester.pump();
      expect(
        (controller.game as KlondikeGame).tableau[0].single.faceUp,
        isTrue,
        reason: 'committed at once',
      );
      await tester.pump(const Duration(milliseconds: 90));
      expect(
        find.byKey(const Key('flip-card-t0-0')),
        findsNothing,
        reason: 'the slide has not landed',
      );
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pump(const Duration(milliseconds: 75));
      final flip = tester.widget<Transform>(
        find.byKey(const Key('flip-card-t0-0')),
      );
      expect(flip.transform.storage[0], lessThan(1));
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.byKey(const Key('flip-card-t0-0')), findsNothing);
      expect(
        tester
            .widget<PlayingCard>(find.byKey(const Key('card-t0-0')))
            .card!
            .faceUp,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tickers(tester), 0);
    },
  );

  testWidgets('undo slides the card back through the midpoint', (tester) async {
    final controller = controllerFor(wasteToColumn);
    await pumpBoard(tester, controller);
    final from = rectOf(tester, 'card-waste-1');
    controller.move(const WastePile(), 1, const TableauPile(0));
    // A pump with a duration advances the clock first, then builds: the
    // plan starts on that build, so a second pump is what lets it finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final to = rectOf(tester, 'card-t0-1');
    expect(
      to.left,
      isNot(closeTo(from.left, 1)),
      reason: 'landed in the column',
    );
    controller.undo();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final mid = rectOf(tester, 'card-waste-1');
    expect(between(mid.left, to.left, from.left), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(rectOf(tester, 'card-waste-1'), from);
  });

  testWidgets(
    'a released drag settles from where the finger left it, in 120 ms',
    (tester) async {
      final controller = controllerFor(wasteToColumn);
      await pumpBoard(tester, controller);
      final home = rectOf(tester, 'card-waste-1');
      final target = rectOf(tester, 'card-t0-0');
      expect(
        controller.beginDrag(const WastePile(), 1, [home, home], home.center),
        isTrue,
      );
      final release = target.center + const Offset(30, 40);
      controller.updateDrag(release);
      await tester.pump();
      final lifted = rectOf(tester, 'card-waste-1');
      expect(controller.endDrag(const TableauPile(0)), isTrue);
      await tester.pump();
      final start = rectOf(tester, 'card-t0-1');
      expect(
        start.left,
        closeTo(lifted.left, 0.5),
        reason: 'from the release point, not the waste',
      );
      expect(start.left, isNot(closeTo(home.left, 1)));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = rectOf(tester, 'card-t0-1');
      await tester.pump(const Duration(milliseconds: 60));
      final end = rectOf(tester, 'card-t0-1');
      expect(
        between(mid.left, start.left, end.left) ||
            between(mid.top, start.top, end.top),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(rectOf(tester, 'card-t0-1'), end);
    },
  );

  testWidgets(
    'a completed Spider run: the King is between the column and its slot at 90 ms',
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
      final kingHome = rectOf(tester, 'card-t0-1');
      final slot = rectOf(tester, 'completed-slot-0');
      controller.move(const TableauPile(1), 0, const TableauPile(0));
      await tester.pump();
      expect((controller.game as SpiderGame).completed, [Suit.spades]);
      expect(
        find.byKey(const Key('completed-0')),
        findsNothing,
        reason: 'hidden until the King lands',
      );
      await tester.pump(const Duration(milliseconds: 90));
      final king = rectOf(tester, 'completed-arriving');
      expect(between(king.left, kingHome.left, slot.left), isTrue);
      expect(between(king.top, kingHome.top, slot.top), isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('completed-arriving')), findsNothing);
      expect(find.byKey(const Key('completed-0')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tickers(tester), 0);
    },
  );

  test('ids: the deal gives every card its deck index; fromPiles matches by rank and suit', () {
    final deck = standardDeck();
    expect(deck.map((c) => c.id), List.generate(52, (i) => i));
    expect(deck[14].id, 14);
    expect(deck[14].up.id, 14);
    expect(
      deck[14].up == deck[14].up.withId(3),
      isTrue,
      reason: 'equality ignores the id',
    );
    final ids = wasteToColumn.tableau[0].single.id;
    expect(ids, Suit.clubs.index * 13 + 12);
    final two = spider(
      tableau: [cards('8S 8S'), [], [], [], [], [], [], [], [], []],
      options: const SpiderOptions(suits: SpiderSuits.one),
    );
    expect(
      two.tableau[0].map((c) => c.id).toSet().length,
      2,
      reason: 'duplicates told apart',
    );
  });
}
