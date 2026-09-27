import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/format.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';

/// The fake elapsed source the clock reads; advanced together with pump.
Duration now = Duration.zero;

/// Advances the fake source and the test clock together, in 100 ms steps so
/// a timer firing at a whole second reads the matching source value.
Future<void> passTime(WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 100);
  while (left > Duration.zero) {
    final s = left < step ? left : step;
    now += s;
    await tester.pump(s);
    left -= s;
  }
}

GameController controllerFor(
  Game game, {
  DisplayOptions options = const DisplayOptions(),
}) => GameController(
  game,
  ValueNotifier(const PlaySettings(oneTap: false)),
  ValueNotifier(options),
  clockNow: () => now,
);

Future<void> pumpBar(WidgetTester tester, GameController controller) async {
  now = Duration.zero;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DisposingHost(
          controller: controller,
          child: SizedBox(
            height: 44,
            width: 390,
            child: TopBar(controller: controller, scale: 1),
          ),
        ),
      ),
    ),
  );
}

String readout(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byKey(const Key('value')),
      ),
    )
    .data!;

void main() {
  group('the clock', () {
    testWidgets('waits for the first move, then ticks once a second', (
      tester,
    ) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBar(tester, controller);
      await passTime(tester, const Duration(seconds: 5));
      expect(controller.game.elapsed, Duration.zero);
      expect(readout(tester, 'readout-time'), '0:00');
      controller.tapPile(const StockPile(), null);
      await tester.pump();
      await passTime(tester, const Duration(seconds: 3));
      expect(controller.game.elapsed, const Duration(seconds: 3));
      expect(readout(tester, 'readout-time'), '0:03');
      expect(readout(tester, 'readout-moves'), 'MOV 1');
    });

    testWidgets('a move mid-second flushes the exact time before it applies', (
      tester,
    ) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBar(tester, controller);
      controller.tapPile(const StockPile(), null);
      await passTime(tester, const Duration(milliseconds: 2500));
      expect(
        controller.game.elapsed,
        const Duration(seconds: 2),
        reason: 'whole seconds so far',
      );
      controller.tapPile(const StockPile(), null);
      expect(
        controller.game.elapsed,
        const Duration(milliseconds: 2500),
        reason: 'flushed at the move',
      );
      await passTime(tester, const Duration(milliseconds: 500));
      expect(
        controller.game.elapsed,
        const Duration(seconds: 3),
        reason: 'the next whole second',
      );
    });

    testWidgets('stops while paused and while the app is not resumed', (
      tester,
    ) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBar(tester, controller);
      controller.tapPile(const StockPile(), null);
      await passTime(tester, const Duration(seconds: 2));
      controller.pause();
      await passTime(tester, const Duration(seconds: 10));
      expect(controller.game.elapsed, const Duration(seconds: 2));
      expect(controller.clock.running, isFalse);
      controller.resume();
      await passTime(tester, const Duration(seconds: 1));
      expect(controller.game.elapsed, const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await passTime(tester, const Duration(seconds: 5));
      expect(controller.game.elapsed, const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await passTime(tester, const Duration(seconds: 5));
      expect(controller.game.elapsed, const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await passTime(tester, const Duration(seconds: 2));
      expect(controller.game.elapsed, const Duration(seconds: 5));
    });

    testWidgets('stops at a win, and resets to waiting on a new game', (
      tester,
    ) async {
      final nearWin = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 12),
        ],
      );
      final controller = controllerFor(nearWin);
      await pumpBar(tester, controller);
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump();
      expect(controller.game.isWon, isTrue);
      await passTime(tester, const Duration(seconds: 5));
      expect(controller.game.elapsed, Duration.zero);
      expect(controller.clock.running, isFalse);
      controller.replaceGame(KlondikeGame.deal(DealNumber(8)));
      await passTime(tester, const Duration(seconds: 5));
      expect(
        controller.game.elapsed,
        Duration.zero,
        reason: 'waiting for the first move again',
      );
      controller.tapPile(const StockPile(), null);
      await passTime(tester, const Duration(seconds: 1));
      expect(controller.game.elapsed, const Duration(seconds: 1));
    });

    testWidgets('undo back to the deal leaves the clock running', (
      tester,
    ) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBar(tester, controller);
      controller.tapPile(const StockPile(), null);
      await passTime(tester, const Duration(seconds: 1));
      final back =
          (controller.game.undo(unlimited: true) as Applied<Game>).game;
      controller.replaceGameKeepingClock(back);
      await passTime(tester, const Duration(seconds: 2));
      expect(controller.game.elapsed, const Duration(seconds: 3));
      expect(controller.game.moves, 0);
    });

    testWidgets('an untimed game still counts play time', (tester) async {
      final controller = controllerFor(
        SpiderGame.deal(DealNumber(11), const SpiderOptions(timed: false)),
      );
      await pumpBar(tester, controller);
      expect(find.byKey(const Key('readout-time')), findsNothing);
      controller.tapPile(const StockPile(), null);
      await passTime(tester, const Duration(seconds: 4));
      expect(controller.game.elapsed, const Duration(seconds: 4));
    });
  });

  group('readouts', () {
    testWidgets('standard shows time, MOV and PTS; the title names the game', (
      tester,
    ) async {
      final controller = controllerFor(
        KlondikeGame.deal(
          DealNumber(7),
          const KlondikeOptions(draw: DrawMode.three),
        ),
      );
      await pumpBar(tester, controller);
      expect(find.text('Klondike · draw 3'), findsOneWidget);
      expect(readout(tester, 'readout-time'), '0:00');
      expect(readout(tester, 'readout-moves'), 'MOV 0');
      expect(readout(tester, 'readout-score'), 'PTS 0');
      expect(find.bySemanticsLabel('Pause, Klondike draw 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Time 0 seconds'), findsOneWidget);
      expect(find.bySemanticsLabel('0 moves'), findsOneWidget);
      expect(find.bySemanticsLabel('Score 0'), findsOneWidget);
    });

    testWidgets(
      'Vegas shows dollars with the minus sign; none hides the score',
      (tester) async {
        final vegas = controllerFor(
          KlondikeGame.deal(
            DealNumber(7),
            const KlondikeOptions(scoring: ScoringMode.vegas),
          ),
        );
        await pumpBar(tester, vegas);
        expect(readout(tester, 'readout-score'), '\$ −\$52');
        expect(find.bySemanticsLabel('Score minus 52 dollars'), findsOneWidget);
        final none = controllerFor(
          KlondikeGame.deal(
            DealNumber(7),
            const KlondikeOptions(scoring: ScoringMode.none),
          ),
        );
        await pumpBar(tester, none);
        expect(find.byKey(const Key('readout-score')), findsNothing);
        expect(find.byKey(const Key('readout-moves')), findsOneWidget);
      },
    );

    testWidgets('Spider shows PTS 500 and its suit count', (tester) async {
      final controller = controllerFor(
        SpiderGame.deal(
          DealNumber(12),
          const SpiderOptions(suits: SpiderSuits.two),
        ),
      );
      await pumpBar(tester, controller);
      expect(find.text('Spider · 2 suits'), findsOneWidget);
      expect(readout(tester, 'readout-score'), 'PTS 500');
      final one = controllerFor(SpiderGame.deal(DealNumber(11)));
      await pumpBar(tester, one);
      expect(find.text('Spider · 1 suit'), findsOneWidget);
    });

    testWidgets(
      'each hide setting removes its readout; untimed hides the time',
      (tester) async {
        final noTimer = controllerFor(
          KlondikeGame.deal(DealNumber(7)),
          options: const DisplayOptions(showTimer: false),
        );
        await pumpBar(tester, noTimer);
        expect(find.byKey(const Key('readout-time')), findsNothing);
        expect(find.byKey(const Key('readout-moves')), findsOneWidget);
        final noScore = controllerFor(
          KlondikeGame.deal(DealNumber(7)),
          options: const DisplayOptions(showMovesAndScore: false),
        );
        await pumpBar(tester, noScore);
        expect(find.byKey(const Key('readout-time')), findsOneWidget);
        expect(find.byKey(const Key('readout-moves')), findsNothing);
        expect(find.byKey(const Key('readout-score')), findsNothing);
        final untimed = controllerFor(
          KlondikeGame.deal(DealNumber(7), const KlondikeOptions(timed: false)),
        );
        await pumpBar(tester, untimed);
        expect(find.byKey(const Key('readout-time')), findsNothing);
        // A timed game with Show timer off still takes the penalty.
        final hidden = controllerFor(
          klondike(
            tableau: [cards('AS'), [], [], [], [], [], []],
            moveScore: 20,
          ),
          options: const DisplayOptions(showTimer: false),
        );
        await pumpBar(tester, hidden);
        hidden.move(const TableauPile(0), 0, const FoundationPile(Suit.spades));
        await passTime(tester, const Duration(seconds: 25));
        expect(hidden.game.score, 30 - 4);
      },
    );

    testWidgets('the pause pill pauses, and is dimmed while paused', (
      tester,
    ) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBar(tester, controller);
      await tester.tap(find.byKey(const Key('pause-pill')));
      await tester.pump();
      expect(controller.isPaused, isTrue);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(const Key('pause-pill')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0.4,
      );
    });
  });

  group('formats', () {
    test('clock, counts, dollars and spoken forms', () {
      expect(formatClock(const Duration(seconds: 65)), '1:05');
      expect(formatClock(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(formatClock(const Duration(hours: 1)), '1:00:00');
      expect(
        formatClock(
          const Duration(hours: 2, minutes: 3, seconds: 4, milliseconds: 900),
        ),
        '2:03:04',
      );
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1234), '1,234');
      expect(formatCount(1234567), '1,234,567');
      expect(formatCount(-52), '−52');
      expect(formatDollars(130), '\$130');
      expect(formatDollars(-52), '−\$52');
      expect(formatDollars(1200), '\$1,200');
      expect(
        spokenTime(const Duration(seconds: 65)),
        'Time 1 minute 5 seconds',
      );
      expect(
        spokenTime(const Duration(hours: 1, seconds: 1)),
        'Time 1 hour 0 minutes 1 second',
      );
      expect(spokenMoves(1), '1 move');
      expect(spokenMoves(12), '12 moves');
    });
  });
}
