import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/navigation.dart';

/// Two pumps flush the setState microtasks and draw; [transition] covers
/// Android's 800 ms route animation.
Future<void> settle(WidgetTester tester, {bool transition = false}) async {
  await tester.pump();
  await tester.pump();
  if (transition) {
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
  }
}

/// Pumps the app on the board (no splash, loads complete) and pushes
/// [screen] over it. [numbers] feeds the deal-number source in order.
Future<GameScope> openScreen(
  WidgetTester tester,
  Widget screen, {
  AppStore? store,
  List<int> numbers = const [5, 42, 43, 44, 45],
  bool overBoard = false,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  var i = 0;
  // A second app in the same test must not reuse the first GameRoot's
  // state (and store): tear the old tree down first.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: store ?? AppStore.memory(),
      showSplash: false,
      dealNumberSource: () => DealNumber(numbers[i++ % numbers.length]),
    ),
  );
  await settle(tester);
  final scope = tester.widget<GameScope>(find.byType(GameScope));
  if (overBoard) {
    tester.state<NavigatorState>(find.byType(Navigator)).push(boardRoute());
    await settle(tester, transition: true);
  }
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(MaterialPageRoute<void>(builder: (_) => screen));
  await settle(tester, transition: true);
  return scope;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
}

/// Gives the controller's live game a move (a stock draw).
void drawFromStock(GameScope scope) =>
    scope.controller.tapPile(const StockPile(), null);

/// The Keep playing button's border and label colours, as drawn (#154).
({Color border, Color text}) keepPlayingColours(
  WidgetTester tester,
  String key,
) {
  final box = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Container),
        ),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .first;
  final label = tester.widget<Text>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
  );
  return (border: (box.border! as Border).top.color, text: label.style!.color!);
}
