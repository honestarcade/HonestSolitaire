import 'dart:ui' show Tristate;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart' as engine;
import 'package:honest_solitaire/ui/a11y/announcer.dart';
import 'package:honest_solitaire/ui/board/board_semantics.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import 'disposing_host.dart';
import 'win_fixtures.dart';

GameController controllerFor(
  Game game, {
  bool oneTap = false,
  bool autoFlip = true,
}) => GameController(
  game,
  ValueNotifier(PlaySettings(oneTap: oneTap)),
  ValueNotifier(const DisplayOptions()),
  dealNumberSource: () => DealNumber(77),
  observeLifecycle: false,
);

/// The board with TalkBack on unless [talkBack] is false; a recording
/// announcer hears what the controller says.
Future<RecordingAnnouncer> pumpBoard(
  WidgetTester tester,
  GameController controller, {
  bool talkBack = true,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: talkBack,
      );
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final announcer = RecordingAnnouncer();
  late BoardAnnouncements announcements;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          announcements = BoardAnnouncements(
            controller,
            announcer,
            () => context,
          );
          return DisposingHost(
            controller: controller,
            child: BoardView(
              controller: controller,
              topBar: (_) => TopBar(controller: controller, scale: 1),
              toolRow: (_) => ToolRow(controller: controller, scale: 1),
            ),
          );
        },
      ),
    ),
  );
  addTearDown(() => announcements.dispose());
  return announcer;
}

SemanticsNode nodeOf(WidgetTester tester, String label) =>
    find.semantics.byLabel(label).evaluate().single;

/// The node's custom actions by label; the tap hint's own action (no
/// label) is not one.
List<String> actionLabels(SemanticsNode node) => [
  for (final id in node.getSemanticsData().customSemanticsActionIds ?? [])
    if (CustomSemanticsAction.getAction(id)!.label != null)
      CustomSemanticsAction.getAction(id)!.label!,
];

void perform(WidgetTester tester, String label, String action) {
  final node = nodeOf(tester, label);
  final id = (node.getSemanticsData().customSemanticsActionIds ?? [])
      .firstWhere((i) => CustomSemanticsAction.getAction(i)!.label == action);
  tester.semantics.performAction(
    find.semantics.byLabel(label),
    SemanticsAction.customAction,
    args: id,
  );
}

void tapNode(WidgetTester tester, String label) => tester.semantics
    .performAction(find.semantics.byLabel(label), SemanticsAction.tap);

/// Column 0: two face-down under 7♥ 6♠; column 1: 8♠ on top; column 2 empty;
/// waste 5♦; hearts foundation to the four.
final sample = klondike(
  tableau: [
    cards('KC* QD* 7H 6S'),
    cards('8S'),
    [],
    cards('9H* 5C'),
    cards('AC'),
    cards('4S'),
    cards('JD'),
  ],
  waste: cards('5D'),
  foundations: [[], suitRun(Suit.hearts, 4), [], []],
);

void main() {
  group('labels', () {
    testWidgets(
      'cards read rank, suit, place and ordinal; piles their name and count',
      (tester) async {
        final controller = controllerFor(sample);
        await pumpBoard(tester, controller);
        for (final label in [
          'Seven of hearts, column 1, 2nd from top',
          'Six of spades, column 1, top card',
          'Column 1, 2 face-down cards',
          'Eight of spades, column 2, top card',
          'Column 3, empty',
          'Column 4, 1 face-down card',
          'Five of diamonds, waste, top card',
          'Waste, 1 card',
          'Stock, empty, double-tap to recycle',
          'Hearts foundation, up to four',
          'Four of hearts, hearts foundation',
          'Spades foundation, empty',
        ]) {
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
        }
        // The painted card's own label is excluded: one node per card.
        expect(find.bySemanticsLabel('Seven of hearts'), findsNothing);
        expect(find.bySemanticsLabel('face-down card'), findsNothing);
      },
    );

    testWidgets('the face-down node names no rank or suit for any column', (
      tester,
    ) async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(7)));
      await pumpBoard(tester, controller);
      final words = RegExp(
        r'\b(ace|two|three|four|five|six|seven|eight|nine|ten|jack|queen|king|spades|hearts|diamonds|clubs)\b',
        caseSensitive: false,
      );
      for (var c = 1; c < 7; c++) {
        final node = tester.getSemantics(find.byKey(Key('sem-down-$c')));
        expect(
          node.label,
          'Column ${c + 1}, $c face-down card${c == 1 ? '' : 's'}',
        );
        expect(words.hasMatch(node.label), isFalse, reason: node.label);
      }
    });

    testWidgets(
      'Spider: stock deals, completed runs, and a selected run reads selected on every card',
      (tester) async {
        final controller = controllerFor(
          spider(
            tableau: [
              cards('9S 8S 7S'),
              cards('10S'),
              [],
              [],
              [],
              [],
              [],
              [],
              [],
              [],
            ],
            stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
            completed: [Suit.spades],
          ),
        );
        await pumpBoard(tester, controller);
        expect(find.bySemanticsLabel('Stock, 1 deal left'), findsOneWidget);
        expect(find.bySemanticsLabel('Completed runs, 1 of 8'), findsOneWidget);
        tapNode(tester, 'Nine of spades, column 1, 3rd from top');
        await tester.pump();
        expect(controller.selection, (const TableauPile(0), 0));
        for (final label in [
          'Nine of spades, column 1, 3rd from top, selected',
          'Eight of spades, column 1, 2nd from top, selected',
          'Seven of spades, column 1, top card, selected',
        ]) {
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
          expect(
            nodeOf(tester, label).getSemanticsData().flagsCollection.isSelected,
            Tristate.isTrue,
          );
        }
      },
    );

    testWidgets(
      'the layer is withdrawn under the pause card and its actions during a drag',
      (tester) async {
        final controller = controllerFor(sample);
        await pumpBoard(tester, controller);
        expect(
          actionLabels(nodeOf(tester, 'Five of diamonds, waste, top card')),
          isNotEmpty,
        );
        controller.pause();
        await tester.pump();
        expect(
          find.bySemanticsLabel('Six of spades, column 1, top card'),
          findsNothing,
        );
        expect(find.bySemanticsLabel('Paused'), findsAtLeastNWidgets(1));
        controller.resume();
        await tester.pump();
        expect(
          find.bySemanticsLabel('Six of spades, column 1, top card'),
          findsOneWidget,
        );
      },
    );
  });

  group('custom actions', () {
    testWidgets(
      'equal the legal destinations, foundation first then columns, and nothing else',
      (tester) async {
        final controller = controllerFor(sample);
        await pumpBoard(tester, controller);
        // 6♠ (top of column 1) goes on nothing: 7♥ is under it; no red seven
        // elsewhere. 5♦ (waste) goes on 6♠ (column 1); no foundation (hearts
        // is at four, diamonds empty). 7♥ starts the 7♥-6♠ run: onto 8♠.
        expect(
          actionLabels(nodeOf(tester, 'Six of spades, column 1, top card')),
          isEmpty,
        );
        expect(
          actionLabels(nodeOf(tester, 'Five of diamonds, waste, top card')),
          ['Move to column 1'],
        );
        expect(
          actionLabels(
            nodeOf(tester, 'Seven of hearts, column 1, 2nd from top'),
          ),
          ['Move to column 2'],
        );
        // A♣ goes to the clubs foundation and onto nothing (a black ace needs a red two).
        expect(
          actionLabels(nodeOf(tester, 'Ace of clubs, column 5, top card')),
          ['Move to clubs foundation'],
        );
        // 4♠ onto 5♦? The waste is not a destination. Onto nothing.
        expect(
          actionLabels(nodeOf(tester, 'Four of spades, column 6, top card')),
          isEmpty,
        );
        // The stock: empty with a waste card → Recycle.
        expect(
          actionLabels(nodeOf(tester, 'Stock, empty, double-tap to recycle')),
          ['Recycle'],
        );
        // The foundation's top card can come back down onto the black five
        // in column 4.
        expect(
          actionLabels(nodeOf(tester, 'Four of hearts, hearts foundation')),
          ['Move to column 4'],
        );
        // The engine agrees: every action is one of legalMoves.
        final legal = controller.game.legalMoves().toSet();
        for (final a in actionsFor(controller.game, const WastePile(), 0)) {
          expect(legal, contains(a.move));
        }
      },
    );

    testWidgets('a King and the empty column; "Turn over" with auto-flip off', (
      tester,
    ) async {
      final controller = controllerFor(
        klondike(
          tableau: [cards('KC'), [], cards('3H*'), [], [], [], []],
          options: const KlondikeOptions(autoFlip: false),
        ),
      );
      await pumpBoard(tester, controller);
      expect(
        actionLabels(nodeOf(tester, 'King of clubs, column 1, top card')),
        [
          'Move to column 2, empty',
          'Move to column 4, empty',
          'Move to column 5, empty',
          'Move to column 6, empty',
          // Column 7 holds the fixture's unmentioned cards: not empty.
        ],
      );
      expect(actionLabels(nodeOf(tester, 'Column 3, 1 face-down card')), [
        'Turn over',
      ]);
      perform(tester, 'Column 3, 1 face-down card', 'Turn over');
      await tester.pump();
      expect(controller.game.moves, 1);
      expect(
        find.bySemanticsLabel('Three of hearts, column 3, top card'),
        findsOneWidget,
      );
    });

    testWidgets('performing an action moves the card and announces it', (
      tester,
    ) async {
      final controller = controllerFor(sample);
      final announcer = await pumpBoard(tester, controller);
      perform(tester, 'Five of diamonds, waste, top card', 'Move to column 1');
      await tester.pump();
      final k = controller.game as KlondikeGame;
      expect(k.waste, isEmpty);
      expect(k.tableau[0].last, const Card(5, Suit.diamonds, faceUp: true));
      expect(announcer.spoken, ['Five of diamonds to column 1']);
      expect(
        find.bySemanticsLabel('Five of diamonds, column 1, top card'),
        findsOneWidget,
      );
    });
  });

  group('taps', () {
    testWidgets(
      'double-tap selects then places, with the selection announced',
      (tester) async {
        final controller = controllerFor(sample);
        final announcer = await pumpBoard(tester, controller);
        tapNode(tester, 'Seven of hearts, column 1, 2nd from top');
        await tester.pump();
        expect(controller.selection, (const TableauPile(0), 2));
        expect(announcer.spoken, ['Seven of hearts and 1 more selected']);
        tapNode(tester, 'Eight of spades, column 2, top card');
        await tester.pump();
        expect(controller.selection, isNull);
        expect((controller.game as KlondikeGame).tableau[1].length, 3);
        expect(
          announcer.spoken.last,
          'Seven of hearts and 1 more to column 2. Card turned: queen of diamonds',
        );
      },
    );

    testWidgets('with TalkBack on a tap always selects, One-tap on or off', (
      tester,
    ) async {
      final controller = controllerFor(sample, oneTap: true);
      await pumpBoard(tester, controller);
      tapNode(tester, 'Ace of clubs, column 5, top card');
      await tester.pump();
      expect(controller.selection, (
        const TableauPile(4),
        0,
      ), reason: 'selected, not sent');
      expect(
        (controller.game as KlondikeGame).foundations[Suit.clubs.index],
        isEmpty,
      );
      controller.dispose();
      // The same tap without a screen reader one-taps it home.
      final plain = controllerFor(sample, oneTap: true);
      await pumpBoard(tester, plain, talkBack: false);
      plain.tapPile(const TableauPile(4), 0);
      await tester.pump();
      expect(plain.selection, isNull);
      expect(
        (plain.game as KlondikeGame).foundations[Suit.clubs.index],
        hasLength(1),
      );
    });

    testWidgets(
      'an empty column and the face-down node are place targets; a tap on nothing clears',
      (tester) async {
        final controller = controllerFor(
          klondike(tableau: [cards('KC'), [], cards('3H* 9S'), [], [], [], []]),
        );
        final announcer = await pumpBoard(tester, controller);
        tapNode(tester, 'King of clubs, column 1, top card');
        await tester.pump();
        tapNode(tester, 'Column 2, empty');
        await tester.pump();
        expect((controller.game as KlondikeGame).tableau[1], cards('KC'));
        expect(announcer.spoken, [
          'King of clubs selected',
          'King of clubs to column 2',
        ]);
        // The face-down node places on its column too.
        tapNode(tester, 'King of clubs, column 2, top card');
        await tester.pump();
        tapNode(tester, 'Column 3, 1 face-down card');
        await tester.pump();
        expect(announcer.spoken.last, "Can't move there");
        expect(controller.selection, isNull);
      },
    );
  });

  group('announcements', () {
    testWidgets('each kind from a fixture', (tester) async {
      final controller = controllerFor(oneMoveFromSolved);
      final announcer = await pumpBoard(tester, controller);
      // A refusal.
      controller.move(const TableauPile(0), 3, const TableauPile(1));
      expect(announcer.spoken.last, "Can't move there");
      // A hint.
      controller.hint();
      expect(announcer.spoken.last, 'Hint: ace of clubs to clubs foundation');
      controller.clearHint();
      // A move to a foundation, which starts the sweep.
      controller.move(const WastePile(), 0, const FoundationPile(Suit.clubs));
      expect(announcer.spoken.sublist(announcer.spoken.length - 2), [
        'Ace of clubs to clubs foundation',
        'Finishing',
      ]);
      await tester.pump(const Duration(seconds: 5));
      expect(controller.game.isWon, isTrue);
      expect(
        announcer.spoken.where((s) => s.startsWith('Finishing')),
        hasLength(1),
        reason: 'the sweep announces Finishing once, the win card the rest',
      );
      controller.dispose();

      // Draw, recycle, undo, restart, new deal.
      final k = controllerFor(
        klondike(
          tableau: [cards('KC'), [], [], [], [], [], []],
          stock: cards('4C* 9D*'),
          waste: cards('2H'),
        ),
      );
      final a = await pumpBoard(tester, k);
      k.tapPile(const StockPile(), null);
      expect(a.spoken.last, 'Drew nine of diamonds');
      k.tapPile(const StockPile(), null, at: const Duration(seconds: 1));
      expect(a.spoken.last, 'Drew four of clubs');
      k.tapPile(const StockPile(), null, at: const Duration(seconds: 2));
      expect(a.spoken.last, 'Stock recycled');
      k.undo();
      expect(a.spoken.last, 'Undone');
      k.restart();
      expect(a.spoken.last, 'Restarted');
      k.newDeal();
      expect(a.spoken.last, 'New deal');
      k.dispose();

      // Spider: a dealt row, a completed run, a refused deal.
      final s = controllerFor(
        spider(
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
          stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        ),
      );
      final sa = await pumpBoard(tester, s);
      s.dealRow();
      expect(sa.spoken.last, "Can't deal: fill every column");
      s.move(const TableauPile(1), 0, const TableauPile(0));
      expect(
        sa.spoken.last,
        'Ace of spades to column 1. Run completed, spades',
      );
    });

    testWidgets('a dealt row and the empty stock', (tester) async {
      final s = controllerFor(
        spider(
          tableau: [
            cards('KS'),
            cards('QS'),
            cards('JS'),
            cards('10S'),
            cards('9S'),
            cards('8S'),
            cards('7S'),
            cards('6S'),
            cards('5S'),
            cards('4S'),
          ],
          stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        ),
      );
      final sa = await pumpBoard(tester, s);
      s.dealRow();
      expect(sa.spoken.last, 'Dealt a row, 0 left');
      s.dealRow();
      expect(sa.spoken.last, 'No deals left');
      s.dispose();
      final k = controllerFor(
        klondike(tableau: [cards('KC'), [], [], [], [], [], []]),
      );
      final ka = await pumpBoard(tester, k);
      k.tapPile(const StockPile(), null);
      expect(ka.spoken.last, 'Stock empty');
    });

    testWidgets('nothing is spoken to the platform without a screen reader', (
      tester,
    ) async {
      final controller = controllerFor(sample);
      // The real announcer under the recording one's seat: no accessible
      // navigation, so it must stay silent.
      final sent = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            (message) async => sent.add('$message'),
          );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await pumpBoard(tester, controller, talkBack: false);
      final element = tester.element(find.byType(BoardView));
      const FlutterAnnouncer().announce(element, 'Hello');
      await tester.pump();
      expect(sent.where((m) => m.contains('Hello')), isEmpty);
    });
  });

  group('describe', () {
    test('hints in words', () {
      final k = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        stock: cards('4C*'),
      );
      expect(
        describeHint(k, const engine.MoveHint(Draw())),
        'Hint: draw a card',
      );
      expect(
        describeHint(k, const engine.MoveHint(Recycle())),
        'Hint: recycle the stock',
      );
      expect(
        describeHint(k, const engine.MoveHint(Flip(2))),
        'Hint: turn over column 3',
      );
      expect(
        describeHint(sample, const engine.MoveHint(WasteToTableau(0))),
        'Hint: five of diamonds to column 1',
      );
      expect(describeHint(k, const engine.NoMovesLeft()), isNull);
    });

    test('ordinals and plurals', () {
      expect(ordinal(0), 'top card');
      expect(ordinal(1), '2nd from top');
      expect(ordinal(2), '3rd from top');
      expect(ordinal(3), '4th from top');
      expect(plural(1, 'card'), '1 card');
      expect(plural(12, 'card'), '12 cards');
    });
  });
}
