import 'dart:ui' show Tristate;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/stats.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/navigation.dart' show boardRoute;
import 'package:honest_solitaire/ui/screens/about_app_screen.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';

import '../engine/positions.dart';
import 'setup_helpers.dart';

/// One control: what TalkBack reads and the state it is in.
class Control {
  const Control(
    this.label, {
    this.button = true,
    this.enabled,
    this.selected,
    this.toggled,
    this.hint,
  });

  /// The exact label, or a pattern.
  final Pattern label;
  final bool button;
  final bool? enabled;
  final bool? selected;
  final bool? toggled;
  final Pattern? hint;

  @override
  String toString() => label is String ? label as String : label.toString();
}

/// Finds the one node whose label matches, and checks its states.
void expectControl(WidgetTester tester, Control c) {
  final finder = find.bySemanticsLabel(c.label);
  expect(finder, findsAtLeastNWidgets(1), reason: '$c: present');
  // A panel may share the label of the button it holds ("Deal"): when a
  // button is expected, the button's node is the one read.
  final nodes = [
    for (final e in finder.evaluate())
      tester.getSemantics(find.byElementPredicate((x) => x == e)),
  ];
  final node = c.button
      ? nodes.firstWhere(
          (n) => n.getSemanticsData().flagsCollection.isButton,
          orElse: () => nodes.first,
        )
      : nodes.first;
  final data = node.getSemanticsData();
  if (c.button) {
    expect(data.flagsCollection.isButton, isTrue, reason: '$c: a button');
  }
  if (c.enabled != null) {
    expect(
      data.flagsCollection.isEnabled,
      c.enabled! ? Tristate.isTrue : Tristate.isFalse,
      reason: '$c: enabled',
    );
  }
  if (c.selected != null) {
    expect(
      data.flagsCollection.isSelected,
      c.selected! ? Tristate.isTrue : Tristate.isFalse,
      reason: '$c: selected',
    );
  }
  if (c.toggled != null) {
    expect(
      data.flagsCollection.isToggled,
      c.toggled! ? Tristate.isTrue : Tristate.isFalse,
      reason: '$c: toggled',
    );
  }
  if (c.hint != null) {
    expect(data.hint, matches(c.hint!), reason: '$c: hint');
  }
}

Future<GameScope> openBoard(WidgetTester tester, Game game) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: AppStore.memory(),
      showSplash: false,
      dealNumberSource: () => DealNumber(77),
    ),
  );
  await settle(tester);
  final scope = tester.widget<GameScope>(find.byType(GameScope));
  scope.controller.replaceGame(game);
  tester.state<NavigatorState>(find.byType(Navigator)).push(boardRoute());
  await settle(tester, transition: true);
  return scope;
}

void main() {
  testWidgets('the menu', (tester) async {
    await openScreen(tester, const SizedBox());
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester, transition: true);
    for (final c in const [
      Control('Klondike, Draw 1 or 3 · four foundations'),
      Control('Spider, 1, 2 or 4 suits · ten columns'),
      Control('Statistics'),
      Control('How to play'),
      Control('Settings'),
      Control('About Honest Arcade, no ads, no tracking, open source'),
    ]) {
      expectControl(tester, c);
    }
    expect(
      find.bySemanticsLabel('Honest Solitaire, by Honest Arcade, no ads'),
      findsOneWidget,
    );
  });

  testWidgets('New Klondike and New Spider', (tester) async {
    await openScreen(tester, const NewKlondikeScreen(), overBoard: true);
    for (final c in const [
      Control('Back'),
      Control('Cards per draw, Draw 1', selected: false),
      Control('Cards per draw, Draw 3', selected: true), // the design default
      Control('Scoring, Standard', selected: true),
      Control('Timer, Timed', selected: true),
      Control('Deal', enabled: true),
    ]) {
      expectControl(tester, c);
    }
    expect(find.bySemanticsLabel('Deal number, optional'), findsOneWidget);
    await openScreen(tester, const NewSpiderScreen());
    for (final c in [
      const Control(
        'Suits in play, Two suits, spades and hearts. The standard game.',
        selected: true,
      ),
      const Control('Timer, Timed', selected: true),
      const Control('Deal', enabled: true),
    ]) {
      expectControl(tester, c);
    }
  });

  testWidgets('Settings: every row toggles with its label and description', (
    tester,
  ) async {
    await openScreen(tester, const SettingsScreen());
    for (final row in [...playRows, ...displayRows, ...soundRows]) {
      await tester.ensureVisible(find.byKey(Key('settings-row-${row.field}')));
      final node = tester.getSemantics(
        find.byKey(Key('settings-row-${row.field}')),
      );
      final data = node.getSemanticsData();
      expect(data.label, row.label, reason: row.field);
      expect(data.hint, row.description, reason: row.field);
      expect(
        data.flagsCollection.isToggled,
        isNot(Tristate.none),
        reason: row.field,
      );
    }
    await tester.ensureVisible(
      find.byKey(const Key('settings-swatch-back-navy')),
    );
    expectControl(tester, const Control('Navy card back', selected: true));
  });

  testWidgets('Statistics', (tester) async {
    final store = AppStore.memory();
    await store.write(
      StoreDoc.stats,
      const StatsDocument(
        klondike: GameStats(
          total: TotalStats(
            played: 184,
            won: 97,
            streak: 4,
            playMs: 60000,
            bestTimeMs: 222000,
            fewestMoves: 118,
            highScore: 2410,
          ),
          modes: {
            'draw1': ModeStats(played: 96, won: 71),
            'draw3': ModeStats(played: 88, won: 26),
          },
          vegas: VegasStats(played: 12, won: 7, dollars: 430),
        ),
      ).toJson(),
    );
    await openScreen(tester, const StatsScreen(), store: store);
    for (final c in const [
      Control('Back'),
      Control('Klondike', selected: true),
      Control('Spider', selected: false),
      Control('Reset statistics'),
    ]) {
      expectControl(tester, c);
    }
    expect(
      find.bySemanticsLabel('Games played, 184, Since install'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Draw three, 26 won of 88, 30 percent'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('stats-reset')));
    await tester.tap(find.byKey(const Key('stats-reset')));
    await settle(tester);
    expectControl(tester, const Control('Reset'));
    expectControl(tester, const Control('Cancel'));
  });

  testWidgets('How to play and About', (tester) async {
    await openScreen(tester, const HowToPlayScreen());
    for (final c in const [
      Control('Back'),
      Control('Klondike', selected: true),
      Control('Spider', selected: false),
    ]) {
      expectControl(tester, c);
    }
    expect(
      find.bySemanticsLabel(RegExp(r'^[A-Z]+\. ')),
      findsAtLeastNWidgets(1),
    );
    await openScreen(tester, const AboutAppScreen());
    for (final c in [
      const Control('Back'),
      const Control('Honest Arcade Promises'),
      const Control('HONEST ARCADE, opens in browser', button: false),
      Control(RegExp(r'^SOURCE ON GITHUB, opens in browser'), button: false),
    ]) {
      expectControl(tester, c);
    }
  });

  testWidgets('the board: top bar, tool row, banner, pause and win cards', (
    tester,
  ) async {
    final scope = await openBoard(
      tester,
      klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        waste: cards('9C 7C 8C'),
        elapsed: const Duration(seconds: 65),
      ),
    );
    for (final c in const [
      Control('Pause, Klondike draw 1', enabled: true),
      Control('Undo', enabled: false),
      Control('Hint', enabled: true),
      Control('Finish', enabled: false),
      Control('Restart', enabled: true),
      Control('New deal', enabled: true),
    ]) {
      expectControl(tester, c);
    }
    expect(find.bySemanticsLabel('Time 1 minute 5 seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('0 moves'), findsOneWidget);
    // The banner: stuck.
    scope.controller.hint();
    await settle(tester);
    expect(find.bySemanticsLabel('No moves left'), findsOneWidget);
    expectControl(tester, const Control('Undo', enabled: false));
    expectControl(tester, const Control('New deal', enabled: true));
    // The pause card.
    scope.controller.pause();
    await settle(tester);
    expect(find.bySemanticsLabel('Paused'), findsAtLeastNWidgets(1));
    for (final label in [
      'Resume',
      'Restart this deal',
      'New deal',
      'Rules',
      'Settings',
      'Main menu',
    ]) {
      expectControl(tester, Control(label));
    }
    scope.controller.resume();
    await settle(tester);
    // The win card.
    scope.controller.replaceGame(
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
    await settle(tester);
    scope.controller.move(
      const TableauPile(0),
      0,
      const FoundationPile(Suit.clubs),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.bySemanticsLabel('Game complete'), findsOneWidget);
    for (final label in ['New deal', 'See statistics', 'Main menu']) {
      expectControl(tester, Control(label));
    }
  });
}
