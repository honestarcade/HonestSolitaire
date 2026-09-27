import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_layout.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/board/win_cascade.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/game/finish_sweep.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';
import 'win_fixtures.dart';

const Size phone = Size(390, 844);

GameController controllerFor(
  Game game, {
  bool animations = true,
  DisplayOptions display = const DisplayOptions(),
}) => GameController(
  game,
  ValueNotifier(PlaySettings(oneTap: false, cardAnimations: animations)),
  ValueNotifier(display),
);

/// The board with animations on unless [reduced] (the phone's switch), the
/// tool row along the bottom, and [winRecord] standing in for the stats
/// listener's future.
Future<void> pumpBoard(
  WidgetTester tester,
  GameController controller, {
  bool reduced = false,
  bool talkBack = false,
  Future<void>? Function()? winRecord,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduced,
        accessibleNavigation: talkBack,
      );
  tester.view.physicalSize = phone * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DisposingHost(
        controller: controller,
        child: BoardView(
          controller: controller,
          winRecord: winRecord,
          toolRow: (_) => ToolRow(controller: controller, scale: 1),
        ),
      ),
    ),
  );
}

BoardViewState boardState(WidgetTester tester) =>
    tester.state<BoardViewState>(find.byType(BoardView));

Map<int, Rect> rects(WidgetTester tester) => boardState(tester).cascadeRects;

/// Seven suits done, the eighth's Ace one move from its run.
final spiderOneFromWon = spider(
  tableau: [
    kingDown(Suit.spades, 2),
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
  completed: List.filled(7, Suit.spades),
);

/// Plays the winning move and pumps to the frame after the win-card delay,
/// where the sequence has started: its slide has landed and the cascade is
/// on its first frame (every card waiting in place).
Future<void> winAndStart(WidgetTester tester, GameController controller) async {
  switch (controller.game) {
    case KlondikeGame():
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
    case SpiderGame():
      controller.move(const TableauPile(1), 0, const TableauPile(0));
  }
  expect(controller.game.isWon, isTrue);
  await tester.pump();
  await tester.pump(winCardDelay);
  // The slide lands over the next frames; the cascade then starts.
  for (var i = 0; i < 10 && rects(tester).isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(rects(tester), isNotEmpty, reason: 'the cascade started');
  expect(controller.winShown, isFalse);
}

/// Pumps [d] in 100 ms frames so tickers advance like on a phone.
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 100);
  while (left > Duration.zero) {
    final s = left < step ? left : step;
    await tester.pump(s);
    left -= s;
  }
}

void main() {
  group('the win cascade', () {
    testWidgets(
      'a won Klondike drops all 52 foundation cards over about two seconds, then the win card',
      (tester) async {
        final controller = controllerFor(nearWin(const KlondikeOptions()));
        await pumpBoard(tester, controller);
        await winAndStart(tester, controller);
        final start = rects(tester);
        expect(start, hasLength(52), reason: 'every card waits in place');
        await tester.pump(const Duration(milliseconds: 100));
        expect(rects(tester), hasLength(52));
        final layout = layoutBoard(
          controller.game,
          phone,
          const DisplayOptions(),
        );
        for (final r in start.values) {
          expect(
            layout.slots.values.any((s) => (s.center - r.center).distance < 1),
            isTrue,
            reason: 'a waiting card sits on its foundation: $r',
          );
        }
        expect(
          find.byKey(const Key('card-f-clubs-12')),
          findsNothing,
          reason: 'the board draws the foundations empty from the first frame',
        );
        expect(find.byKey(const Key('cascade-0')), findsOneWidget);

        await pumpFor(tester, const Duration(milliseconds: 800));
        final mid = rects(tester);
        expect(mid.length, lessThan(52), reason: 'the first cards have left');
        expect(mid.length, greaterThan(10), reason: 'the last still wait');
        final moving = mid.entries.where(
          (e) => e.value.top > start[e.key]!.top + 1,
        );
        expect(moving, isNotEmpty, reason: 'cards in flight move down');
        for (final e in moving) {
          expect(
            e.value.left,
            isNot(closeTo(start[e.key]!.left, 0.01)),
            reason: 'a falling card drifts sideways',
          );
        }
        expect(controller.winShown, isFalse);

        await pumpFor(tester, const Duration(milliseconds: 600));
        expect(
          controller.winShown,
          isFalse,
          reason: 'the last card leaves at 2.0 s',
        );
        await pumpFor(tester, const Duration(milliseconds: 700));
        await tester.pump();
        expect(rects(tester), isEmpty);
        expect(controller.winShown, isTrue);
        expect(find.byKey(const Key('win-card')), findsOneWidget);
        expect(
          find.byKey(const Key('card-f-clubs-12')),
          findsNothing,
          reason: 'the foundations stay empty behind the win card',
        );
      },
    );

    testWidgets(
      'a won Spider drops its eight Kings at tableau size, then the win card',
      (tester) async {
        final controller = controllerFor(spiderOneFromWon);
        await pumpBoard(tester, controller);
        await winAndStart(tester, controller);
        final start = rects(tester);
        expect(start, hasLength(8));
        final layout = layoutBoard(
          controller.game,
          phone,
          const DisplayOptions(),
        );
        for (final r in start.values) {
          expect(r.size, layout.cardSize, reason: 'a King at tableau size');
        }
        final kings = tester.widgetList<PlayingCard>(
          find.byWidgetPredicate(
            (w) =>
                w is PlayingCard &&
                w.key.toString().contains('cascade-') &&
                w.card?.isKing == true,
          ),
        );
        expect(kings, hasLength(8));
        expect(find.byKey(const Key('completed-0')), findsNothing);
        await pumpFor(tester, const Duration(milliseconds: 2100));
        await tester.pump();
        expect(controller.winShown, isTrue);
        expect(find.byKey(const Key('completed-0')), findsNothing);
      },
    );

    testWidgets('a tap on the board shows the win card on the next frame', (
      tester,
    ) async {
      final controller = controllerFor(nearWin(const KlondikeOptions()));
      await pumpBoard(tester, controller);
      await winAndStart(tester, controller);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(rects(tester), isNotEmpty);
      await tester.tapAt(const Offset(195, 500));
      await tester.pump();
      expect(controller.winShown, isTrue);
      expect(find.byKey(const Key('win-card')), findsOneWidget);
      expect(rects(tester), isEmpty);
    });

    testWidgets(
      'card animations off, or the phone removing animations: the win card with no cascade frame',
      (tester) async {
        for (final reduced in [false, true]) {
          final controller = controllerFor(
            nearWin(const KlondikeOptions()),
            animations: reduced, // the setting off, or the phone's switch
          );
          await pumpBoard(tester, controller, reduced: reduced);
          controller.move(
            const TableauPile(0),
            0,
            const FoundationPile(Suit.clubs),
          );
          await tester.pump();
          expect(rects(tester), isEmpty);
          await tester.pump(winCardDelay);
          expect(rects(tester), isEmpty, reason: 'reduced=$reduced');
          expect(controller.winShown, isTrue, reason: 'reduced=$reduced');
          await tester.pump();
          expect(find.byKey(const Key('win-card')), findsOneWidget);
          expect(
            find.byKey(const Key('card-f-clubs-12')),
            findsNothing,
            reason: 'foundations empty behind the card, cascade or not',
          );
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets('with TalkBack there is no cascade frame either', (
      tester,
    ) async {
      final controller = controllerFor(nearWin(const KlondikeOptions()));
      await pumpBoard(tester, controller, talkBack: true);
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump();
      expect(rects(tester), isEmpty, reason: 'no cascade frame under TalkBack');
      await tester.pump(winCardDelay);
      expect(rects(tester), isEmpty);
      expect(controller.winShown, isTrue);
      await tester.pump();
      expect(find.byKey(const Key('win-card')), findsOneWidget);
    });

    testWidgets(
      'the win is recorded before the first cascade frame; a record that never completes starts it at 2 s',
      (tester) async {
        final record = Completer<void>();
        var asked = 0;
        final controller = controllerFor(nearWin(const KlondikeOptions()));
        await pumpBoard(
          tester,
          controller,
          winRecord: () {
            asked++;
            return record.future;
          },
        );
        controller.move(
          const TableauPile(0),
          0,
          const FoundationPile(Suit.clubs),
        );
        await tester.pump();
        await tester.pump(winCardDelay);
        expect(asked, 1, reason: 'the sequence asked for the record');
        await pumpFor(tester, const Duration(milliseconds: 1500));
        expect(
          rects(tester),
          isEmpty,
          reason: 'no cascade frame before the record completes',
        );
        expect(controller.winShown, isFalse);
        await pumpFor(tester, const Duration(milliseconds: 600));
        expect(
          rects(tester),
          isNotEmpty,
          reason: 'a record that never completes starts the cascade at 2 s',
        );
        await tester.pumpWidget(const SizedBox());

        final prompt = Completer<void>();
        final second = controllerFor(nearWin(const KlondikeOptions()));
        await pumpBoard(tester, second, winRecord: () => prompt.future);
        second.move(const TableauPile(0), 0, const FoundationPile(Suit.clubs));
        await tester.pump();
        await tester.pump(winCardDelay);
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(rects(tester), isEmpty);
        prompt.complete();
        await pumpFor(tester, const Duration(milliseconds: 300));
        expect(rects(tester), isNotEmpty, reason: 'the record done, it starts');
      },
    );

    testWidgets('a record that throws starts the cascade anyway', (
      tester,
    ) async {
      final controller = controllerFor(nearWin(const KlondikeOptions()));
      await pumpBoard(
        tester,
        controller,
        winRecord: () => Future<void>.error(StateError('disk')),
      );
      await winAndStart(tester, controller);
      expect(rects(tester), hasLength(52));
    });

    testWidgets(
      'the tool row stays live: RESTART during the cascade acts and ends it, no win card; UNDO is out (the engine refuses an undo past a win)',
      (tester) async {
        final controller = controllerFor(nearWin(const KlondikeOptions()));
        await pumpBoard(tester, controller);
        await winAndStart(tester, controller);
        await pumpFor(tester, const Duration(milliseconds: 300));
        expect(controller.canUndo, isFalse);
        expect(
          tester
              .widget<Opacity>(
                find.ancestor(
                  of: find.byKey(const Key('tool-restart')),
                  matching: find.byType(Opacity),
                ),
              )
              .opacity,
          1.0,
          reason: 'RESTART is enabled during the cascade',
        );
        await tester.tap(find.byKey(const Key('tool-restart')));
        await tester.pump();
        expect(controller.game.isWon, isFalse, reason: 'the deal restarted');
        expect(rects(tester), isEmpty, reason: 'the cascade ended');
        await tester.pump();
        expect(controller.winShown, isFalse, reason: 'no card: not won');
        expect(find.byKey(const Key('win-card')), findsNothing);
        await tester.pump(const Duration(milliseconds: 200)); // button release
      },
    );
  });

  group('planCascade', () {
    test('Klondike leaves suit by suit in on-screen order, King first, spread to 1.6 s, drift alternating', () {
      final game = klondike(
        tableau: [[], [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 13),
        ],
      );
      for (final leftHanded in [false, true]) {
        final options = DisplayOptions(leftHanded: leftHanded);
        final layout = layoutBoard(game, phone, options);
        final plan = planCascade(game, layout, width: phone.width);
        expect(plan.cards, hasLength(52));
        final bySlot = [
          for (final suit in Suit.values)
            (layout.slots[FoundationPile(suit)]!.left, suit),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        for (var p = 0; p < 4; p++) {
          final pile = plan.cards.sublist(p * 13, p * 13 + 13);
          expect(
            pile.map((c) => c.card.suit).toSet(),
            {bySlot[p].$2},
            reason:
                'pile $p is the ${p + 1}th slot from the left '
                '(leftHanded=$leftHanded)',
          );
          expect(
            pile.map((c) => c.card.rank),
            List.generate(13, (i) => 13 - i),
            reason: 'King first',
          );
          expect(
            pile.first.drift.sign,
            p.isEven ? -1 : 1,
            reason: 'drift alternates by on-screen pile',
          );
          expect(pile.first.drift.abs(), driftAtDesignWidth);
        }
        expect(plan.cards.first.startMs, 0);
        expect(plan.cards.last.startMs, cascadeSpread.inMilliseconds);
        expect(plan.totalMs, (cascadeSpread + fallDuration).inMilliseconds);
        final starts = plan.cards.map((c) => c.startMs).toList();
        for (var i = 1; i < starts.length; i++) {
          expect(starts[i] - starts[i - 1], inInclusiveRange(31, 32));
        }
      }
    });

    test('a card eases down past the screen and drifts linearly', () {
      const from = Rect.fromLTWH(100, 200, 50, 70);
      const card = FallingCard(
        card: Card(kingRank, Suit.spades, faceUp: true),
        from: from,
        startMs: 100,
        drift: 24,
        order: 0,
      );
      expect(card.rectAt(0, 844), from);
      expect(card.rectAt(100, 844), from);
      final half = card.rectAt(300, 844);
      expect(half.left, 100 + 12, reason: 'linear drift at half time');
      expect(
        half.top - from.top,
        lessThan((844 + 70 - 200) / 2),
        reason: 'ease-in: less than half way down at half time',
      );
      expect(half.top, greaterThan(from.top));
      final end = card.rectAt(500, 844);
      expect(end.top, greaterThanOrEqualTo(844), reason: 'off the bottom');
      expect(card.goneAt(500), isTrue);
      expect(card.goneAt(499), isFalse);
    });

    test('drift scales with the board width', () {
      final game = klondike(
        tableau: [[], [], [], [], [], [], []],
        foundations: [suitRun(Suit.spades, 13), [], [], []],
      );
      final layout = layoutBoard(game, phone, const DisplayOptions());
      final narrow = planCascade(game, layout, width: 195);
      expect(narrow.cards.first.drift.abs(), driftAtDesignWidth / 2);
    });
  });
}
