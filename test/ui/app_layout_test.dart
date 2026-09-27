import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';

import '../engine/positions.dart';

const dpr = 2.75;
const topInset = 24.0;
const bottomInset = 48.0;

Future<GameController> pumpApp(WidgetTester tester, Size logical) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logical * dpr;
  // Both: the board reads viewPadding (the bars), Material reads padding.
  final insets = FakeViewPadding(
    top: topInset * dpr,
    bottom: bottomInset * dpr,
  );
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    HonestSolitaireApp(dealNumberSource: () => DealNumber(17)),
  );
  return tester.widget<GameScope>(find.byType(GameScope)).controller;
}

/// Every card and the tool row stay inside the safe area.
void expectInsideSafeArea(WidgetTester tester, Size logical) {
  final safe = Rect.fromLTRB(
    0,
    topInset,
    logical.width,
    logical.height - bottomInset,
  );
  var cards = 0;
  for (final element in find.byType(PlayingCard).evaluate()) {
    final rect = tester.getRect(find.byWidget(element.widget));
    cards++;
    expect(
      rect.top,
      greaterThanOrEqualTo(safe.top - 0.01),
      reason: '$logical card top $rect',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(safe.bottom + 0.01),
      reason: '$logical card bottom $rect',
    );
    expect(
      rect.left,
      greaterThanOrEqualTo(safe.left - 0.01),
      reason: '$logical card left $rect',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(safe.right + 0.01),
      reason: '$logical card right $rect',
    );
  }
  expect(cards, greaterThan(0));
  final undo = tester.getRect(find.byKey(const Key('tool-undo')));
  expect(
    undo.bottom,
    lessThanOrEqualTo(safe.bottom + 0.01),
    reason: '$logical tool row',
  );
  expect(undo.top, greaterThan(safe.top));
  expect(undo.height, greaterThanOrEqualTo(48));
}

void main() {
  final tallKlondike = klondike(
    tableau: [
      [
        for (var i = 0; i < 6; i++) standardDeck()[i],
        for (var i = 6; i < 30; i++) standardDeck()[i].up,
      ],
      [],
      [],
      [],
      [],
      [],
      [],
    ],
  );

  for (final size in const [Size(320, 568), Size(390, 844), Size(480, 1000)]) {
    testWidgets(
      'at ${size.width.toInt()}×${size.height.toInt()} nothing leaves the safe area',
      (tester) async {
        final controller = await pumpApp(tester, size);
        expectInsideSafeArea(tester, size);
        controller.replaceGame(tallKlondike);
        await tester.pump();
        expectInsideSafeArea(tester, size);
        controller.replaceGame(
          SpiderGame.deal(
            DealNumber(12),
            const SpiderOptions(suits: SpiderSuits.two),
          ),
        );
        await tester.pump();
        expectInsideSafeArea(tester, size);
      },
    );
  }

  testWidgets('the board is capped at 480 and centred on a wide screen', (
    tester,
  ) async {
    await pumpApp(tester, const Size(600, 1000));
    final left = tester.getRect(find.byKey(const Key('card-t0-0'))).left;
    expect(left, closeTo(60 + 12 * 480 / 390, 0.5));
  });

  testWidgets('display settings apply at once without restarting the game', (
    tester,
  ) async {
    final controller = await pumpApp(tester, const Size(390, 844));
    final scope = tester.widget<GameScope>(find.byType(GameScope));
    for (var i = 0; i < 3; i++) {
      controller.tapPile(const StockPile(), null);
    }
    await tester.pump();
    expect(controller.game.moves, 3);
    final stockBefore = tester.getRect(
      find.byKey(const Key('card-stock-0'), skipOffstage: false),
    );
    scope.displayOptions.value = scope.displayOptions.value.copyWith(
      leftHanded: true,
    );
    await tester.pump();
    final stockAfter = tester.getRect(
      find.byKey(const Key('card-stock-0'), skipOffstage: false),
    );
    expect(
      stockAfter.left,
      greaterThan(stockBefore.left),
      reason: 'the stock moved to the right',
    );
    expect(controller.game.dealNumber.value, 17);
    expect(controller.game.moves, 3);
    scope.displayOptions.value = scope.displayOptions.value.copyWith(
      largeCards: true,
    );
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('card-t0-0'))),
      const Size(52, 78),
    );
    expect(controller.game.moves, 3);
    scope.displayOptions.value = scope.displayOptions.value.copyWith(
      cardBack: CardBack.teal,
    );
    await tester.pump();
    final down = tester.widget<PlayingCard>(
      find.byKey(const Key('card-t6-0'), skipOffstage: false),
    );
    expect(down.card!.faceUp, isFalse);
    expect(down.back, CardBack.teal);
    expect(controller.game.dealNumber.value, 17);
    expect(controller.game.moves, 3);
  });

  testWidgets('the launch options are the design\'s and NEW keeps them', (
    tester,
  ) async {
    final controller = await pumpApp(tester, const Size(390, 844));
    final game = controller.game as KlondikeGame;
    expect(game.options, launchOptions);
    controller.newDeal();
    expect((controller.game as KlondikeGame).options, launchOptions);
    expect(find.text('BY HONEST ARCADE'), findsNothing);
  });
}
