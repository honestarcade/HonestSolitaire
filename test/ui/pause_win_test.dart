import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/board/win_cascade.dart';
import 'package:honest_solitaire/ui/game/finish_sweep.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/pause_card.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';
import 'package:honest_solitaire/ui/game/win_card.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import 'disposing_host.dart';
import 'win_fixtures.dart';

var nextDeal = 700;

GameController controllerFor(
  Game game, {
  PlaySettings settings = const PlaySettings(oneTap: false),
}) => GameController(
  game,
  ValueNotifier(settings),
  ValueNotifier(const DisplayOptions()),
  dealNumberSource: () => DealNumber(nextDeal++),
);

Future<void> pumpBoard(WidgetTester tester, GameController controller) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DisposingHost(
        controller: controller,
        child: BoardView(
          controller: controller,
          topBar: (_) => TopBar(controller: controller, scale: 1),
          toolRow: (_) => ToolRow(controller: controller, scale: 1),
        ),
      ),
    ),
  );
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

/// With animations on, #104's cascade runs between the win and the card:
/// pumps through it and returns how long that took.
Future<Duration> pumpThroughCascade(
  WidgetTester tester,
  GameController controller,
) async {
  var elapsed = Duration.zero;
  var sawCascade = false;
  const step = Duration(milliseconds: 100);
  while (!controller.winShown && elapsed < const Duration(seconds: 6)) {
    await tester.pump(step);
    elapsed += step;
    final state = tester.state<BoardViewState>(find.byType(BoardView));
    if (state.cascadeRects.isNotEmpty) sawCascade = true;
  }
  expect(sawCascade, isTrue, reason: 'the cascade ran before the card');
  // Coarse pumps put the cascade's clock up to a frame ahead: the exact
  // timing is win_cascade_test's.
  expect(
    elapsed,
    greaterThanOrEqualTo(cascadeSpread),
    reason: 'the card waits for the cascade',
  );
  return elapsed;
}

void main() {
  group('the pause card', () {
    testWidgets(
      'shows the mode line with the deal number and its buttons, and no more',
      (tester) async {
        final controller = controllerFor(
          KlondikeGame.deal(
            DealNumber(48213),
            const KlondikeOptions(draw: DrawMode.three),
          ),
        );
        await pumpBoard(tester, controller);
        controller.tapPile(const StockPile(), null);
        await tester.pump();
        expect(find.byKey(const Key('pause-card')), findsNothing);
        await tester.tap(find.byKey(const Key('pause-pill')));
        await tester.pump();
        expect(controller.isPaused, isTrue);
        expect(find.byKey(const Key('pause-card')), findsOneWidget);
        expect(find.text('Paused'), findsOneWidget);
        expect(
          find.text('KLONDIKE · DRAW 3 · 0:00 · DEAL #48213'),
          findsOneWidget,
        );
        for (final label in [
          'Resume',
          'Restart this deal',
          'New deal',
          'Rules',
          'Settings',
          'Main menu',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.textContaining('Switch to'), findsNothing);
        expect(
          controller.clock.running,
          isFalse,
          reason: 'the clock stops under the card',
        );
        // The scrim swallows taps.
        await tester.tapAt(const Offset(20, 300));
        await tester.pump();
        expect(controller.isPaused, isTrue);
        await tester.tap(find.byKey(const Key('pause-resume')));
        await tester.pump();
        expect(controller.isPaused, isFalse);
        expect(find.byKey(const Key('pause-card')), findsNothing);
        expect(controller.clock.running, isTrue);
      },
    );

    test('the mode line names Vegas, no score, untimed and Spider', () {
      expect(
        pauseMeta(nearWin(const KlondikeOptions(scoring: ScoringMode.vegas))),
        'KLONDIKE · DRAW 1 · VEGAS · 2:00 · DEAL #48213',
      );
      expect(
        pauseMeta(
          nearWin(
            const KlondikeOptions(scoring: ScoringMode.none, timed: false),
          ),
        ),
        'KLONDIKE · DRAW 1 · NO SCORE · DEAL #48213',
      );
      expect(
        pauseMeta(
          SpiderGame.deal(
            DealNumber(5),
            const SpiderOptions(suits: SpiderSuits.two),
          ),
        ),
        'SPIDER · 2 SUITS · 0:00 · DEAL #5',
      );
      expect(
        pauseMeta(
          SpiderGame.deal(DealNumber(5), const SpiderOptions(timed: false)),
        ),
        'SPIDER · 1 SUIT · DEAL #5',
      );
    });

    testWidgets(
      'Restart this deal restores the deal at once; New deal deals afresh',
      (tester) async {
        final deal = KlondikeGame.deal(DealNumber(9));
        final controller = controllerFor(deal);
        await pumpBoard(tester, controller);
        controller.tapPile(const StockPile(), null);
        controller.pause();
        await tester.pump();
        await tester.tap(find.byKey(const Key('pause-restart')));
        await tester.pump();
        expect(controller.game, deal);
        expect(controller.isPaused, isFalse);
        expect(
          controller.clock.running,
          isFalse,
          reason: 'waiting for a first move',
        );
        controller.pause();
        await tester.pump();
        await tester.tap(find.byKey(const Key('pause-new')));
        await tester.pump();
        expect(controller.game.dealNumber.value, isNot(9));
        expect(controller.isPaused, isFalse);
      },
    );

    testWidgets(
      'system back pauses, then resumes; returning from the background pauses',
      (tester) async {
        final controller = controllerFor(KlondikeGame.deal(DealNumber(9)));
        await pumpBoard(tester, controller);
        await back(tester);
        expect(controller.isPaused, isTrue);
        await back(tester);
        expect(controller.isPaused, isFalse);
        // Before the first move, backgrounding does not open the card.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(controller.isPaused, isFalse);
        controller.tapPile(const StockPile(), null);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(controller.isPaused, isFalse, reason: 'inactive alone does not');
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(controller.isPaused, isTrue);
        expect(find.byKey(const Key('pause-card')), findsOneWidget);
      },
    );
  });

  group('auto-finish', () {
    // The stepping is what these assert: animations on (#99 turns them
    // off for every test by default).
    setUp(() {
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
    });
    testWidgets(
      'on: a move that solves the board sweeps it step by step to the win card',
      (tester) async {
        final controller = controllerFor(oneMoveFromSolved);
        await pumpBoard(tester, controller);
        controller.move(const WastePile(), 0, const TableauPile(5));
        await tester.pump();
        expect(controller.finishing, isTrue);
        expect(
          controller.game.isWon,
          isTrue,
          reason: 'committed at once, one undo step',
        );
        expect(controller.game.historyLength, 2);
        expect(
          controller.shown.isWon,
          isFalse,
          reason: 'the board still shows the start',
        );
        expect(controller.clock.running, isFalse);
        expect(find.byKey(const Key('win-card')), findsNothing);
        // Taps are ignored during the sweep.
        controller.tapPile(const TableauPile(0), 0);
        expect(controller.selection, isNull);
        await tester.pump(sweepStep);
        final afterOne = controller.shown;
        expect(afterOne.moves, 2, reason: 'one step shown');
        await tester.pump(sweepStep);
        expect(controller.shown.moves, 3);
        await tester.pump(sweepStep * 30);
        expect(controller.shown.isWon, isTrue);
        expect(controller.finishing, isFalse);
        await tester.pump(winCardDelay);
        // #104: the cascade runs first (animations are on here).
        expect(controller.winShown, isFalse);
        await pumpThroughCascade(tester, controller);
        expect(controller.winShown, isTrue);
        expect(find.byKey(const Key('win-card')), findsOneWidget);
        expect(find.text('GAME COMPLETE'), findsOneWidget);
        expect(find.text('Foundations complete'), findsOneWidget);
      },
    );

    testWidgets('off: nothing happens until FINISH', (tester) async {
      final controller = controllerFor(
        oneMoveFromSolved,
        settings: const PlaySettings(oneTap: false, autoFinish: false),
      );
      await pumpBoard(tester, controller);
      controller.move(const WastePile(), 0, const TableauPile(5));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.finishing, isFalse);
      expect(controller.game.isWon, isFalse);
      expect(controller.canFinish, isTrue);
      await tester.tap(find.byKey(const Key('tool-finish')));
      await tester.pump();
      expect(controller.finishing, isTrue);
      await tester.pump(sweepStep * 40 + winCardDelay);
      expect(controller.winShown, isFalse, reason: '#104: the cascade first');
      await pumpThroughCascade(tester, controller);
      expect(controller.winShown, isTrue);
    });

    testWidgets(
      'pausing mid-sweep completes it and shows the win card, not the pause card',
      (tester) async {
        final controller = controllerFor(oneMoveFromSolved);
        await pumpBoard(tester, controller);
        controller.move(const WastePile(), 0, const TableauPile(5));
        await tester.pump(sweepStep * 3);
        await back(tester);
        expect(controller.finishing, isFalse);
        expect(controller.shown.isWon, isTrue);
        expect(controller.isPaused, isFalse);
        // Completing at once jumps straight to the card: no cascade (#104).
        expect(controller.winShown, isTrue);
        expect(find.byKey(const Key('win-card')), findsOneWidget);
        // Back on the win card does nothing.
        await back(tester);
        expect(find.byKey(const Key('win-card')), findsOneWidget);
      },
    );
  });

  group('the win card', () {
    Future<void> winWith(WidgetTester tester, GameController controller) async {
      await pumpBoard(tester, controller);
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('win-card')),
        findsNothing,
        reason: 'not before 250 ms',
      );
      await tester.pump(winCardDelay);
      expect(find.byKey(const Key('win-card')), findsOneWidget);
    }

    testWidgets(
      'a timed standard win shows TIME, MOVES, SCORE and TIME BONUS',
      (tester) async {
        final controller = controllerFor(nearWin(const KlondikeOptions()));
        await winWith(tester, controller);
        expect(find.text('TIME'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('win-card')),
            matching: find.text('2:00'),
          ),
          findsOneWidget,
          reason: 'the top bar shows the time too',
        );
        expect(find.text('MOVES'), findsOneWidget);
        expect(find.text('SCORE'), findsOneWidget);
        expect(find.text('TIME BONUS'), findsOneWidget);
        expect(find.text('+5,833'), findsOneWidget);
        expect(
          find.text(
            controller.game.score.toString().replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+$)'),
              (m) => '${m[1]},',
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('win-new')), findsOneWidget);
        expect(find.text('See statistics'), findsOneWidget);
        expect(find.text('Main menu'), findsOneWidget);
        expect(
          find.text('STREAK'),
          findsNothing,
          reason: 'no statistics without the app scope',
        );
        expect(controller.clock.running, isFalse);
      },
    );

    testWidgets(
      'Vegas shows DOLLARS; none hides the score; untimed shows no time or bonus',
      (tester) async {
        await winWith(
          tester,
          controllerFor(
            nearWin(const KlondikeOptions(scoring: ScoringMode.vegas)),
          ),
        );
        expect(find.text('DOLLARS'), findsOneWidget);
        expect(find.text('\$45'), findsOneWidget);
        expect(find.text('TIME BONUS'), findsNothing);
        await winWith(
          tester,
          controllerFor(
            nearWin(
              const KlondikeOptions(scoring: ScoringMode.none, timed: false),
            ),
          ),
        );
        expect(find.text('SCORE'), findsNothing);
        expect(find.text('DOLLARS'), findsNothing);
        expect(find.text('TIME'), findsNothing);
        expect(find.text('MOVES'), findsOneWidget);
      },
    );

    testWidgets('New deal on the win card deals a new game of the same kind', (
      tester,
    ) async {
      final controller = controllerFor(
        nearWin(const KlondikeOptions(draw: DrawMode.three)),
      );
      await winWith(tester, controller);
      await tester.tap(find.byKey(const Key('win-new')));
      await tester.pump();
      expect(find.byKey(const Key('win-card')), findsNothing);
      expect(controller.game.isWon, isFalse);
      expect((controller.game as KlondikeGame).options.draw, DrawMode.three);
      expect(controller.winShown, isFalse);
    });

    test('winCells omits what the game lacks', () {
      expect(
        winCells(nearWin(const KlondikeOptions(timed: false))).map((c) => c.$1),
        ['MOVES', 'SCORE'],
      );
      expect(winCells(SpiderGame.deal(DealNumber(1))).map((c) => c.$1), [
        'TIME',
        'MOVES',
        'SCORE',
      ]);
    });
  });
}
