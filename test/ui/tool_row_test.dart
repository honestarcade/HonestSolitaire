import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/board/slot_painter.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/game/finish_sweep.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';
import 'package:honest_solitaire/ui/game/ui_hint.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';
import 'package:honest_solitaire/ui/theme/palette.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';

import 'package:honest_solitaire/ui/icons/glyphs.dart';

var nextDeal = 500;

GameController controllerFor(
  Game game, {
  PlaySettings settings = const PlaySettings(oneTap: false),
  DisplayOptions options = const DisplayOptions(),
}) => GameController(
  game,
  ValueNotifier(settings),
  ValueNotifier(options),
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

Future<void> press(WidgetTester tester, String tool) async {
  await tester.tap(find.byKey(Key('tool-$tool')), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

double opacityOf(WidgetTester tester, String tool) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(Key('tool-$tool')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

CardRing ringOf(WidgetTester tester, String key) =>
    tester.widget<PlayingCard>(find.byKey(Key(key))).ring;

Duration _clock = Duration.zero;
Future<void> tapCard(WidgetTester tester, String key) async {
  _clock += const Duration(milliseconds: 500);
  final rect = tester.getRect(find.byKey(Key(key)));
  final g = await tester.createGesture();
  await g.down(Offset(rect.center.dx, rect.top + 3), timeStamp: _clock);
  await g.up(timeStamp: _clock);
  await tester.pump();
}

void main() {
  testWidgets(
    'UNDO is disabled at the deal, enabled after a move, and undoes it',
    (tester) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBoard(tester, controller);
      expect(opacityOf(tester, 'undo'), 0.4);
      expect(find.bySemanticsLabel('Undo'), findsOneWidget);
      controller.tapPile(const StockPile(), null);
      await tester.pump();
      expect(opacityOf(tester, 'undo'), 1);
      await press(tester, 'undo');
      expect(controller.game.moves, 0);
      expect(controller.game, KlondikeGame.deal(DealNumber(7)));
      expect(opacityOf(tester, 'undo'), 0.4);
    },
  );

  testWidgets('limited undo disables after one undo until the next move', (
    tester,
  ) async {
    final controller = controllerFor(
      KlondikeGame.deal(DealNumber(7)),
      settings: const PlaySettings(oneTap: false, unlimitedUndo: false),
    );
    await pumpBoard(tester, controller);
    final position = klondike(
      tableau: [cards('8H* 7S 6D'), cards('8D'), cards('9C'), [], [], [], []],
    );
    controller.replaceGame(position);
    await tester.pump();
    controller.move(const TableauPile(0), 1, const TableauPile(1));
    controller.move(const TableauPile(1), 1, const TableauPile(0));
    await tester.pump();
    expect(controller.game.moves, 2);
    await press(tester, 'undo');
    expect(controller.game.moves, 1);
    expect(opacityOf(tester, 'undo'), 0.4, reason: 'one undo per move');
    await press(tester, 'undo');
    expect(controller.game.moves, 1);
    controller.move(const TableauPile(1), 1, const TableauPile(0));
    await tester.pump();
    expect(opacityOf(tester, 'undo'), 1);
  });

  testWidgets(
    'HINT rings the source run and its destination, and clears on the next tap',
    (tester) async {
      final position = klondike(
        tableau: [cards('8H* 7S 6D'), cards('8D'), cards('9C'), [], [], [], []],
      );
      final controller = controllerFor(position);
      await pumpBoard(tester, controller);
      await press(tester, 'hint');
      expect(
        controller.currentHint,
        const UiHint.move(
          source: TableauPile(0),
          start: 1,
          destination: TableauPile(1),
        ),
      );
      expect(ringOf(tester, 'card-t0-1'), CardRing.hinted);
      expect(ringOf(tester, 'card-t0-2'), CardRing.hinted);
      expect(ringOf(tester, 'card-t0-0'), CardRing.none);
      expect(
        ringOf(tester, 'card-t1-0'),
        CardRing.hinted,
        reason: 'the destination\'s top card',
      );
      expect(ringOf(tester, 'card-t2-0'), CardRing.none);
      // Pressing HINT again hides it.
      await press(tester, 'hint');
      expect(controller.currentHint, isNull);
      expect(ringOf(tester, 'card-t0-1'), CardRing.none);
      await press(tester, 'hint');
      await tapCard(tester, 'card-t2-0');
      expect(controller.currentHint, isNull, reason: 'any tap clears it');
    },
  );

  testWidgets(
    'a draw hint rings the stock; an empty destination column turns amber',
    (tester) async {
      final draw = klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        stock: cards('QD*'),
      );
      final controller = controllerFor(draw);
      await pumpBoard(tester, controller);
      await press(tester, 'hint');
      expect(controller.currentHint, const UiHint.stock());
      expect(ringOf(tester, 'card-stock-0'), CardRing.hinted);
      final king = klondike(
        tableau: [cards('QD* KS'), [], cards('KH'), [], [], [], []],
      );
      controller.replaceGame(king);
      await tester.pump();
      await press(tester, 'hint');
      expect(controller.currentHint?.destination, const TableauPile(1));
      final slot =
          tester.widget<CustomPaint>(find.byKey(const Key('slot-t1'))).painter
              as SlotPainter;
      expect(slot.edgeColor, Palette.hintRing);
    },
  );

  testWidgets(
    'no moves left shows the banner in place of the readouts, with working buttons',
    (tester) async {
      final stuck = klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        waste: cards('9C 7C 8C'),
      );
      final controller = controllerFor(stuck);
      await pumpBoard(tester, controller);
      expect(find.byKey(const Key('readout-moves')), findsOneWidget);
      await press(tester, 'hint');
      expect(controller.currentHint, const UiHint.noMoves());
      expect(find.byKey(const Key('no-moves-banner')), findsOneWidget);
      expect(find.text('No moves left'), findsOneWidget);
      expect(
        find.byKey(const Key('readout-moves')),
        findsNothing,
        reason: 'the readouts give way',
      );
      expect(
        find.bySemanticsLabel('Undo'),
        findsNWidgets(2),
        reason: 'the banner\'s and the tool row\'s',
      );
      // Undo is disabled here (nothing to undo); New deal deals afresh.
      final undoButton = find.byKey(const Key('notice-undo'));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: undoButton, matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        0.4,
      );
      await tester.tap(find.byKey(const Key('notice-new-deal')));
      await tester.pump();
      expect(controller.game.dealNumber.value, isNot(1));
      expect(controller.currentHint, isNull);
      expect(find.byKey(const Key('no-moves-banner')), findsNothing);
      expect(find.byKey(const Key('readout-moves')), findsOneWidget);
      // Pressing HINT while the banner shows hides it.
      controller.replaceGame(stuck);
      await tester.pump();
      await press(tester, 'hint');
      expect(find.byKey(const Key('no-moves-banner')), findsOneWidget);
      await press(tester, 'hint');
      expect(find.byKey(const Key('no-moves-banner')), findsNothing);
    },
  );

  testWidgets('FINISH is disabled until the board can finish, then sweeps it', (
    tester,
  ) async {
    final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
    await pumpBoard(tester, controller);
    expect(opacityOf(tester, 'finish'), 0.4);
    final solved = klondike(
      tableau: [
        cards('KC QD JC 10D'),
        cards('KD QC JD 10C 9D 8C'),
        cards('9C 8D 7C 6D'),
        [],
        cards('7D 6C 5D 4C 3D 2C'),
        cards('5C 4D 3C 2D'),
        cards('AD AC'),
      ],
      foundations: [suitRun(Suit.spades, 13), suitRun(Suit.hearts, 13), [], []],
    );
    controller.replaceGame(solved);
    await tester.pump();
    expect(opacityOf(tester, 'finish'), 1);
    await press(tester, 'finish');
    expect(controller.game.isWon, isTrue);
    expect(controller.game.historyLength, 1, reason: 'one undo step');
  });

  testWidgets(
    'DEAL shows the rows left, deals, and is refused like the stock',
    (tester) async {
      final controller = controllerFor(
        SpiderGame.deal(
          DealNumber(12),
          const SpiderOptions(suits: SpiderSuits.two),
        ),
      );
      await pumpBoard(tester, controller);
      expect(find.text('DEAL 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Deal, 5 left'), findsOneWidget);
      expect(find.byKey(const Key('tool-finish')), findsNothing);
      await press(tester, 'deal');
      expect((controller.game as SpiderGame).rowsLeft, 4);
      expect(find.text('DEAL 4'), findsOneWidget);
      final strict = spider(
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
      controller.replaceGame(strict);
      await tester.pump();
      expect(
        opacityOf(tester, 'deal'),
        1,
        reason: 'enabled under the strict rule so the refusal teaches it',
      );
      await press(tester, 'deal');
      expect(controller.game, strict);
      expect(controller.shake?.pile, const StockPile());
      await tester.pump(shakeDuration + const Duration(milliseconds: 20));
      final empty = spider(
        tableau: [
          cards('7H'),
          cards('KS'),
          cards('KS'),
          cards('KS'),
          cards('KS'),
          cards('KH'),
          cards('KH'),
          cards('KH'),
          cards('KH'),
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      controller.replaceGame(empty);
      await tester.pump();
      expect(find.text('DEAL 0'), findsOneWidget);
      expect(opacityOf(tester, 'deal'), 0.4);
    },
  );

  testWidgets(
    'a stock tap within 300 ms of pressing DEAL is debounced (#137)',
    (tester) async {
      final controller = controllerFor(
        SpiderGame.deal(
          DealNumber(12),
          const SpiderOptions(suits: SpiderSuits.two),
        ),
      );
      await pumpBoard(tester, controller);

      final dealRect = tester.getRect(find.byKey(const Key('tool-deal')));
      final press1 = await tester.createGesture();
      await press1.down(dealRect.center, timeStamp: const Duration(seconds: 1));
      await press1.up(timeStamp: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect((controller.game as SpiderGame).rowsLeft, 4);

      final stockRect = tester.getRect(find.byKey(const Key('stock-sliver-0')));
      final tap2 = await tester.createGesture();
      await tap2.down(
        stockRect.center,
        timeStamp: const Duration(milliseconds: 1150),
      );
      await tap2.up(timeStamp: const Duration(milliseconds: 1150));
      await tester.pump();
      expect(
        (controller.game as SpiderGame).rowsLeft,
        4,
        reason: 'too soon after DEAL, same as too soon after a stock tap',
      );

      final tap3 = await tester.createGesture();
      await tap3.down(
        stockRect.center,
        timeStamp: const Duration(milliseconds: 1550),
      );
      await tap3.up(timeStamp: const Duration(milliseconds: 1550));
      await tester.pump();
      expect((controller.game as SpiderGame).rowsLeft, 3);
    },
  );

  testWidgets(
    'NEW deals a different number with the same options; RESTART returns to the same deal',
    (tester) async {
      final controller = controllerFor(
        KlondikeGame.deal(
          DealNumber(7),
          const KlondikeOptions(draw: DrawMode.three),
        ),
      );
      await pumpBoard(tester, controller);
      controller.tapPile(const StockPile(), null);
      await tester.pump();
      await press(tester, 'restart');
      expect(
        controller.game,
        KlondikeGame.deal(
          DealNumber(7),
          const KlondikeOptions(draw: DrawMode.three),
        ),
      );
      expect(controller.game.moves, 0);
      await press(tester, 'new');
      final fresh = controller.game as KlondikeGame;
      expect(fresh.dealNumber.value, isNot(7));
      expect(fresh.options, const KlondikeOptions(draw: DrawMode.three));
      expect(fresh.moves, 0);
      // A number matching the current deal is rerolled.
      nextDeal = fresh.dealNumber.value;
      await press(tester, 'new');
      expect(
        (controller.game as KlondikeGame).dealNumber.value,
        isNot(fresh.dealNumber.value),
      );
    },
  );

  testWidgets('left-handed reverses the order; glyphs and labels are present', (
    tester,
  ) async {
    final controller = controllerFor(
      KlondikeGame.deal(DealNumber(7)),
      options: const DisplayOptions(leftHanded: true),
    );
    await pumpBoard(tester, controller);
    final undo = tester.getCenter(find.byKey(const Key('tool-undo')));
    final fresh = tester.getCenter(find.byKey(const Key('tool-new')));
    expect(undo.dx, greaterThan(fresh.dx), reason: 'UNDO is now on the right');
    for (final glyph in [
      Glyph.undo,
      Glyph.hint,
      Glyph.finish,
      Glyph.restart,
      Glyph.newGame,
    ]) {
      expect(
        find.byWidgetPredicate((w) => w is GlyphIcon && w.glyph == glyph),
        findsOneWidget,
        reason: glyph.name,
      );
    }
    for (final label in ['UNDO', 'HINT', 'FINISH', 'RESTART', 'NEW']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.getSize(find.byKey(const Key('tool-undo'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    'won: HINT and FINISH disable at once, the rest with the win card; HINT is silent then',
    (tester) async {
      final controller = controllerFor(
        klondike(
          tableau: [cards('KC'), [], [], [], [], [], []],
          foundations: [
            suitRun(Suit.spades, 13),
            suitRun(Suit.hearts, 13),
            suitRun(Suit.diamonds, 13),
            suitRun(Suit.clubs, 12),
          ],
        ),
      );
      await pumpBoard(tester, controller);
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump();
      expect(controller.game.isWon, isTrue);
      expect(controller.winShown, isFalse);
      // #104: RESTART and NEW act through the cascade and end it; UNDO is
      // out because the engine refuses an undo past a win.
      for (final tool in ['restart', 'new']) {
        expect(opacityOf(tester, tool), 1.0, reason: tool);
      }
      expect(controller.canUndo, isFalse);
      for (final tool in ['undo', 'hint', 'finish']) {
        expect(opacityOf(tester, tool), 0.4, reason: tool);
      }
      controller.hint();
      expect(controller.currentHint, isNull);
      await tester.pump(winCardDelay);
      expect(controller.winShown, isTrue);
      for (final tool in ['undo', 'hint', 'finish', 'restart', 'new']) {
        expect(opacityOf(tester, tool), 0.4, reason: tool);
      }
    },
  );
}
