import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import 'disposing_host.dart';
import 'setup_helpers.dart';

GameController controllerFor(Game game) => GameController(
  game,
  ValueNotifier(const PlaySettings(oneTap: false)),
  ValueNotifier(const DisplayOptions()),
  dealNumberSource: () => DealNumber(9),
);

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
        child: BoardView(
          controller: controller,
          topBar: (_) => TopBar(controller: controller, scale: 1),
        ),
      ),
    ),
  );
}

Rect rectOf(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key)));
int tickers(WidgetTester tester) => tester.binding.transientCallbackCount;

/// The rects of every tableau card, by key.
Map<String, Rect> tableauRects(WidgetTester tester, Game game) {
  final columns = switch (game) {
    KlondikeGame k => k.tableau,
    SpiderGame s => s.tableau,
  };
  return {
    for (var c = 0; c < columns.length; c++)
      for (var i = 0; i < columns[c].length; i++)
        'card-t$c-$i': rectOf(tester, 'card-t$c-$i'),
  };
}

void main() {
  testWidgets(
    'a cold start shows the board dealt at once; a new deal flies: between the stock and the columns at 300 ms, landed by 600 ms',
    (tester) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
      await pumpBoard(tester, controller);
      expect(tickers(tester), 0, reason: 'no deal on a cold start');
      final settled = tableauRects(tester, controller.game);
      final stock = rectOf(tester, 'slot-stock');
      controller.newDeal();
      await tester.pump();
      final atStart = tableauRects(tester, controller.game);
      expect(
        atStart.values.every(
          (r) =>
              (r.left - stock.left).abs() < 0.5 &&
              (r.top - stock.top).abs() < 0.5,
        ),
        isTrue,
        reason: 'stacked at the stock before the first frame',
      );
      await tester.pump(const Duration(milliseconds: 300));
      final mid = tableauRects(tester, controller.game);
      final flying = mid.entries
          .where((e) => e.value != atStart[e.key] && e.value != settled[e.key])
          .length;
      expect(
        flying,
        greaterThan(0),
        reason: 'cards between the stock and their columns',
      );
      expect(
        mid.entries.where(
          (e) =>
              e.value == settled[e.key] ||
              (e.value.left - settled[e.key]!.left).abs() < 0.01,
        ),
        isNotEmpty,
        reason: 'the first cards have landed',
      );
      await tester.pump(const Duration(milliseconds: 300));
      final landed = tableauRects(tester, controller.game);
      for (final e in landed.entries) {
        // By the centre: a card mid-flip is scaled about it, and settled
        // cards snap to a device pixel.
        final c = e.value.center;
        final s = settled[e.key]!.center;
        expect(
          (c.dx - s.dx).abs() < 0.5 && (c.dy - s.dy).abs() < 0.5,
          isTrue,
          reason: '${e.key} landed by 600 ms',
        );
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(tickers(tester), 0, reason: 'the flips are done');
    },
  );

  testWidgets(
    'a restart deals again; a resume shows the final layout with no ticker',
    (tester) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
      await pumpBoard(tester, controller);
      final stock = rectOf(tester, 'slot-stock');
      controller.restart();
      await tester.pump();
      expect(rectOf(tester, 'card-t6-6').left, closeTo(stock.left, 0.5));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tickers(tester), 0);
      final settled = rectOf(tester, 'card-t6-6');
      controller.resumeGame(KlondikeGame.deal(DealNumber(5)), hasMove: true);
      await tester.pump();
      expect(
        rectOf(tester, 'card-t6-6'),
        settled,
        reason: 'in place on the first frame',
      );
      expect(tickers(tester), 0);
      expect(controller.pendingDeal, 1, reason: 'a resume raises no token');
    },
  );

  testWidgets(
    'a board tap mid-deal lands it at once and selects nothing; a pause lands it too',
    (tester) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
      await pumpBoard(tester, controller);
      controller.newDeal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final gesture = await tester.createGesture();
      final target = rectOf(tester, 'card-t6-6');
      await gesture.down(
        Offset(target.center.dx, target.top + 3),
        timeStamp: const Duration(milliseconds: 500),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 500));
      await tester.pump();
      expect(controller.selection, isNull, reason: 'the tap was consumed');
      expect(tickers(tester), 0, reason: 'landed at once');
      final landed = rectOf(tester, 'card-t6-6');
      await tester.pump(const Duration(milliseconds: 300));
      expect(rectOf(tester, 'card-t6-6'), landed);
      // The next tap acts normally.
      await gesture.down(
        Offset(landed.center.dx, landed.top + 3),
        timeStamp: const Duration(milliseconds: 1500),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 1500));
      await tester.pump();
      expect(controller.selection, isNotNull);
      // A pause mid-deal.
      controller.newDeal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.pause();
      await tester.pump();
      expect(find.byKey(const Key('pause-card')), findsOneWidget);
      expect(tickers(tester), 0, reason: 'the deal landed under the card');
    },
  );

  testWidgets(
    'a pause-pill tap mid-deal opens the pause card with the deal finished',
    (tester) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
      await pumpBoard(tester, controller);
      controller.newDeal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('pause-pill')));
      await tester.pump();
      expect(controller.isPaused, isTrue);
      expect(find.byKey(const Key('pause-card')), findsOneWidget);
      expect(tickers(tester), 0);
    },
  );

  testWidgets('with reduced motion there is no deal', (tester) async {
    final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
    await pumpBoard(tester, controller, reduced: true);
    final settled = tableauRects(tester, controller.game);
    controller.newDeal();
    await tester.pump();
    final now = tableauRects(tester, controller.game);
    expect(
      now.values.every(
        (r) => settled.values.any(
          (s) => (s.left - r.left).abs() < 0.01 && (s.top - r.top).abs() < 0.01,
        ),
      ),
      isTrue,
    );
    expect(tickers(tester), 0);
  });

  testWidgets('Spider deals from its next-row sliver', (tester) async {
    final controller = controllerFor(
      SpiderGame.deal(
        DealNumber(3),
        const SpiderOptions(suits: SpiderSuits.two),
      ),
    );
    await pumpBoard(tester, controller);
    final sliver = rectOf(tester, 'stock-sliver-0');
    controller.newDeal();
    await tester.pump();
    final start = rectOf(tester, 'card-t9-4');
    expect(start.left, closeTo(sliver.left, 0.5));
    expect(start.top, closeTo(sliver.top, 0.5));
    expect(
      find.byKey(const Key('stock-sliver-0')),
      findsOneWidget,
      reason: 'the sliver stays drawn',
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tickers(tester), 0);
  });

  testWidgets(
    'the setup screen\'s Deal raises the deal token; Keep playing does not',
    (tester) async {
      final scope = await openScreen(tester, const NewKlondikeScreen());
      expect(scope.controller.pendingDeal, 0);
      await tapKey(tester, 'ksetup-deal');
      await settle(tester, transition: true);
      expect(scope.controller.pendingDeal, 1);
    },
  );
}
