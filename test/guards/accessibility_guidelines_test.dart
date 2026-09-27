@Tags(['guard', 'slow'])
library;

// Every control on every screen has a label and a guideline-sized tap
// target (#109): the framework's tap-target, labeled-tap-target and text-
// contrast guidelines over every screen and board state, on a small and a
// normal phone, at 1.0× and 1.3× text. The one exception (owner, round
// two) is a board node as wide as its card — tagged in the app, listed
// here with its reason and its other way to act, and never silent: every
// flagged node must carry the tag, and every tappable exempt kind must have
// been needed somewhere in this suite.

import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/stats.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/navigation.dart';
import 'package:honest_solitaire/ui/screens/about_app_screen.dart';
import 'package:honest_solitaire/ui/screens/about_studio_screen.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/screens/loading_screen.dart';
import 'package:honest_solitaire/ui/screens/menu_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';

import '../engine/positions.dart';
import '../helpers/a11y.dart';
import '../helpers/fonts.dart';

const dpr = 2.75;
const insets = FakeViewPadding(top: 24 * dpr, bottom: 48 * dpr);
const sizes = [Size(320, 568), Size(390, 844)];
const scales = [1.0, 1.3];

/// The exception, in full: what is exempt, why, and how a player acts on
/// it instead. Only the tappable kinds can be flagged; each of those must
/// be, somewhere in the suite, or the exemption is stale.
const exemptKinds =
    <String, ({String reason, String alternative, bool tappable})>{
      'fanned card': (
        reason: 'a tableau card is as wide as its card, narrower than 48 dp on a small phone',
        alternative:
            'its custom actions (the legal destinations) or a tap that selects',
        tappable: true,
      ),
      'face-down group': (
        reason: 'a column\'s face-down cards are one node the width of a card',
        alternative: 'a tap that places on the column, or "Turn over"',
        tappable: true,
      ),
      'waste card': (
        reason: 'the waste\'s top card is the width of a card',
        alternative: 'its custom actions, or a tap that selects',
        tappable: true,
      ),
      'completed slot': (
        reason: 'Spider\'s completed runs are one read-only node',
        alternative: 'none needed: it is not tappable, so the guideline never measures it',
        tappable: false,
      ),
    };

String? kindOf(Flagged f) {
  final l = f.label;
  if (l.contains('face-down card')) return 'face-down group';
  if (l.contains(', waste, ')) return 'waste card';
  if (RegExp(r', column \d+, ').hasMatch(l)) return 'fanned card';
  if (l.startsWith('Completed runs')) return 'completed slot';
  return null;
}

/// Every kind the suite needed an exemption for.
final kindsNeeded = <String>{};

class FakeDealer implements DealerHandle {
  final controller = StreamController<DealerEvent>();
  @override
  Stream<DealerEvent> get events => controller.stream;
  @override
  Future<void> cancel() async => controller.add(const Cancelled());
}

FakeDealer? lastDealer;

final fullStats = StatsDocument(
  klondike: GameStats(
    total: const TotalStats(
      played: 184,
      won: 97,
      streak: 4,
      playMs: 40830000,
      bestTimeMs: 222000,
      fewestMoves: 118,
      highScore: 2410,
    ),
    modes: const {
      'draw1': ModeStats(played: 96, won: 71),
      'draw3': ModeStats(played: 88, won: 26),
    },
    vegas: const VegasStats(played: 12, won: 7, dollars: -430),
  ),
  spider: GameStats(
    total: const TotalStats(
      played: 126,
      won: 41,
      streak: 2,
      playMs: 50580000,
      bestTimeMs: 485000,
      fewestMoves: 96,
      highScore: 1180,
    ),
    modes: const {
      'suits1': ModeStats(played: 40, won: 20),
      'suits2': ModeStats(played: 40, won: 15),
      'suits4': ModeStats(played: 46, won: 6),
    },
  ),
);

/// Klondike draw 3, Vegas, stuck: every node kind, and HINT raises the
/// banner.
final klondikeBoard = klondike(
  tableau: [
    cards('KC* QD* 7H 6S'),
    cards('KH'),
    [],
    cards('9H* 5C'),
    cards('AC'),
    cards('4S'),
    cards('JD'),
  ],
  waste: cards('9C 7C 8C'),
  foundations: [[], suitRun(Suit.hearts, 4), [], []],
  options: const KlondikeOptions(
    draw: DrawMode.three,
    scoring: ScoringMode.vegas,
  ),
  moveScore: -52,
  moves: 12,
  elapsed: const Duration(minutes: 3, seconds: 5),
);

/// Spider two suits with a stock row, a completed run and face-down cards.
final spiderBoard = spider(
  tableau: [
    cards('9S* 8S 7S'),
    cards('10H'),
    cards('KS* QH'),
    [],
    cards('3H'),
    cards('2S'),
    cards('AH'),
    cards('5S'),
    cards('4H'),
    cards('JS'),
  ],
  stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
  completed: [Suit.spades],
  options: const SpiderOptions(suits: SpiderSuits.two),
);

/// One screen or state to prove.
class A11yCase {
  const A11yCase(this.name, this.setup, {this.expect, this.minTappable = 3});

  final String name;

  /// Puts the app into the state; the scope is the app's, the navigator its.
  final Future<void> Function(
    WidgetTester tester,
    GameScope scope,
    NavigatorState nav,
  )
  setup;

  /// The widget type expected on top (non-vacuity).
  final Type? expect;
  final int minTappable;

  @override
  String toString() => name;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> push(
  WidgetTester tester,
  NavigatorState nav,
  Widget screen,
) async {
  nav.push(FadePageRoute<void>(builder: (_) => screen));
  await settle(tester);
}

Future<void> board(
  WidgetTester tester,
  GameScope scope,
  NavigatorState nav,
  Game game,
) async {
  scope.controller.replaceGame(game);
  nav.push(boardRoute());
  await settle(tester);
}

Future<void> win(
  WidgetTester tester,
  GameScope scope,
  NavigatorState nav, {
  required bool spider,
}) async {
  await board(
    tester,
    scope,
    nav,
    spider
        ? spider_(
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
          )
        : klondike(
            tableau: [cards('KC'), [], [], [], [], [], []],
            foundations: [
              suitRun(Suit.spades, 13),
              suitRun(Suit.hearts, 13),
              suitRun(Suit.diamonds, 13),
              suitRun(Suit.clubs, 12),
            ],
          ),
  );
  if (spider) {
    scope.controller.move(const TableauPile(1), 0, const TableauPile(0));
  } else {
    scope.controller.move(
      const TableauPile(0),
      0,
      const FoundationPile(Suit.clubs),
    );
  }
  // Animations are off (flutter_test_config): the card follows the delay.
  await tester.pump(const Duration(milliseconds: 300));
  await settle(tester);
}

SpiderGame spider_({
  required List<List<Card>> tableau,
  List<Suit> completed = const [],
}) => spider(tableau: tableau, completed: completed);

final cases = <A11yCase>[
  A11yCase('menu', (t, s, n) async {}, expect: MenuScreen, minTappable: 6),
  A11yCase(
    'menu with banner and Continue',
    (t, s, n) async {
      s.store.corruptionNotices.value = {StoreDoc.stats};
      s.controller.replaceGame(klondikeBoard);
      s.controller.tapPile(const TableauPile(1), 0);
      s.controller.tapPile(const TableauPile(1), 0);
      await settle(t);
    },
    expect: MenuScreen,
    minTappable: 7,
  ),
  A11yCase(
    'new Klondike',
    (t, s, n) => push(t, n, const NewKlondikeScreen()),
    expect: NewKlondikeScreen,
    minTappable: 8,
  ),
  A11yCase(
    'new Klondike from a board with a typed deal number',
    (t, s, n) async {
      await board(t, s, n, klondikeBoard);
      s.controller.tapPile(const TableauPile(1), 0);
      s.controller.tapPile(const TableauPile(1), 0);
      await push(t, n, const NewKlondikeScreen());
      await t.enterText(find.byKey(const Key('deal-number-field')), '48213');
      await settle(t);
    },
    expect: NewKlondikeScreen,
    minTappable: 9,
  ),
  A11yCase(
    'new Klondike with an invalid deal number',
    (t, s, n) async {
      await push(t, n, const NewKlondikeScreen());
      await t.enterText(find.byKey(const Key('deal-number-field')), '0');
      await settle(t);
    },
    expect: NewKlondikeScreen,
    minTappable: 8,
  ),
  A11yCase(
    'new Spider',
    (t, s, n) => push(t, n, const NewSpiderScreen()),
    expect: NewSpiderScreen,
    minTappable: 8,
  ),
  A11yCase(
    'searching',
    (t, s, n) async {
      await push(t, n, LoadingScreen.search(options: const KlondikeOptions()));
      lastDealer!.controller.add(const Progress(120, Duration(seconds: 2)));
      await settle(t);
    },
    expect: LoadingScreen,
    minTappable: 1,
  ),
  A11yCase(
    'search at the soft limit',
    (t, s, n) async {
      await push(t, n, LoadingScreen.search(options: const KlondikeOptions()));
      lastDealer!.controller.add(const SoftLimitReached());
      await settle(t);
    },
    expect: LoadingScreen,
    minTappable: 2,
  ),
  A11yCase(
    'search found nothing',
    (t, s, n) async {
      await push(t, n, LoadingScreen.search(options: const KlondikeOptions()));
      lastDealer!.controller.add(const NotFound());
      await settle(t);
    },
    expect: LoadingScreen,
    minTappable: 2,
  ),
  A11yCase(
    'settings',
    (t, s, n) => push(t, n, const SettingsScreen()),
    expect: SettingsScreen,
    minTappable: 10,
  ),
  A11yCase(
    'statistics, Klondike',
    (t, s, n) => push(t, n, const StatsScreen()),
    expect: StatsScreen,
    minTappable: 4,
  ),
  A11yCase(
    'statistics, Spider',
    (t, s, n) async {
      await push(t, n, const StatsScreen(game: GameType.spider));
    },
    expect: StatsScreen,
    minTappable: 4,
  ),
  A11yCase(
    'statistics, reset confirm',
    (t, s, n) async {
      await push(t, n, const StatsScreen());
      await t.ensureVisible(find.byKey(const Key('stats-reset')));
      await t.tap(find.byKey(const Key('stats-reset')));
      await settle(t);
    },
    expect: StatsScreen,
    minTappable: 4,
  ),
  A11yCase(
    'how to play, Klondike',
    (t, s, n) => push(t, n, const HowToPlayScreen()),
    expect: HowToPlayScreen,
    minTappable: 3,
  ),
  A11yCase(
    'how to play, Spider',
    (t, s, n) => push(t, n, const HowToPlayScreen(game: GameType.spider)),
    expect: HowToPlayScreen,
    minTappable: 3,
  ),
  A11yCase(
    'about the app',
    (t, s, n) => push(t, n, const AboutAppScreen()),
    expect: AboutAppScreen,
    minTappable: 2,
  ),
  A11yCase(
    'about the app with the snackbar',
    (t, s, n) async {
      await push(t, n, const AboutAppScreen());
      final link = find.bySemanticsLabel('HONEST ARCADE, opens in browser');
      await t.ensureVisible(link);
      await t.tap(link);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
    },
    expect: AboutAppScreen,
    minTappable: 2,
  ),
  A11yCase(
    'about Honest Arcade',
    (t, s, n) => push(t, n, const AboutStudioScreen()),
    expect: AboutStudioScreen,
    minTappable: 2,
  ),
  for (final spider in [false, true]) ...[
    A11yCase(
      '${spider ? 'Spider' : 'Klondike'} board',
      (t, s, n) => board(t, s, n, spider ? spiderBoard : klondikeBoard),
      expect: BoardView,
      minTappable: 12,
    ),
    A11yCase(
      '${spider ? 'Spider' : 'Klondike'} board, large cards',
      (t, s, n) async {
        s.displayOptions.value = s.displayOptions.value.copyWith(
          largeCards: true,
        );
        await board(t, s, n, spider ? spiderBoard : klondikeBoard);
      },
      expect: BoardView,
      minTappable: 12,
    ),
    A11yCase(
      '${spider ? 'Spider' : 'Klondike'} board, paused',
      (t, s, n) async {
        await board(t, s, n, spider ? spiderBoard : klondikeBoard);
        s.controller.pause();
        await settle(t);
      },
      expect: BoardView,
      minTappable: 6,
    ),
    A11yCase(
      '${spider ? 'Spider' : 'Klondike'} board, won',
      (t, s, n) => win(t, s, n, spider: spider),
      expect: BoardView,
      minTappable: 3,
    ),
    A11yCase(
      '${spider ? 'Spider' : 'Klondike'} board, banner',
      (t, s, n) async {
        await board(
          t,
          s,
          n,
          spider
              ? spider_(
                  tableau: [
                    cards('KS'),
                    cards('KS'),
                    [],
                    [],
                    [],
                    [],
                    [],
                    [],
                    [],
                    [],
                  ],
                )
              : klondike(
                  tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
                  waste: cards('9C 7C 8C'),
                ),
        );
        s.controller.hint();
        await settle(t);
      },
      expect: BoardView,
      minTappable: 6,
    ),
  ],
];

/// The nodes with a tap or long-press, for non-vacuity.
int tappable(WidgetTester tester) {
  var n = 0;
  void visit(SemanticsNode node) {
    final d = node.getSemanticsData();
    if (!node.isMergedIntoParent &&
        (d.hasAction(SemanticsAction.tap) ||
            d.hasAction(SemanticsAction.longPress))) {
      n++;
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    visit(view.owner!.semanticsOwner!.rootSemanticsNode!);
  }
  return n;
}

Future<void> check(WidgetTester tester, String label, A11yCase c) async {
  if (c.expect != null) {
    expect(
      find.byType(c.expect!),
      findsWidgets,
      reason: '$label: ${c.expect} on top',
    );
  }
  expect(
    tappable(tester),
    greaterThanOrEqualTo(c.minTappable),
    reason: '$label: not vacuous',
  );
  final flagged = <Flagged>[];
  await expectLater(
    tester,
    meetsGuideline(RecordingTapTargetGuideline(flagged)),
    reason: label,
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: label,
  );
  await expectLater(
    tester,
    meetsGuideline(const CheckedTextGuideline()),
    reason: label,
  );
  for (final f in flagged) {
    expect(f.tagged, isTrue, reason: '$label: $f is not exempt');
    final kind = kindOf(f);
    expect(
      kind,
      isNotNull,
      reason: '$label: $f is tagged but is no listed kind',
    );
    expect(exemptKinds[kind]!.tappable, isTrue, reason: '$label: $f');
    kindsNeeded.add(kind!);
    // Its other way to act: custom actions, or the selecting/placing tap.
    expect(
      f.actions.isNotEmpty || f.label.isNotEmpty,
      isTrue,
      reason: '$label: $f has no alternative',
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final size in sizes) {
    for (final scale in scales) {
      for (final c in cases) {
        final label =
            '$c @ ${size.width.toInt()}×${size.height.toInt()} $scale×';
        testWidgets(label, (tester) async {
          tester.view.physicalSize = size * dpr;
          tester.view.devicePixelRatio = dpr;
          tester.view.padding = insets;
          tester.view.viewPadding = insets;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = AppStore.memory();
          await store.write(StoreDoc.stats, fullStats.toJson());
          await tester.pumpWidget(
            HonestSolitaireApp(
              store: store,
              showSplash: false,
              search: (_, _) => lastDealer = FakeDealer(),
              dealNumberSource: () => DealNumber(48213),
              initialDisplayOptions: const DisplayOptions(
                showTimer: true,
                showMovesAndScore: true,
              ),
            ),
          );
          await settle(tester);
          final scope = tester.widget<GameScope>(find.byType(GameScope));
          final nav = tester.state<NavigatorState>(find.byType(Navigator));
          await c.setup(tester, scope, nav);
          final handle = tester.ensureSemantics();
          await settle(tester);
          await check(tester, label, c);
          // Scrollable screens: the end too.
          final scrollables = find.byType(Scrollable).evaluate();
          if (scrollables.isNotEmpty && c.expect != BoardView) {
            final position =
                (scrollables.first as StatefulElement).state as ScrollableState;
            if (position.position.maxScrollExtent > 0) {
              position.position.jumpTo(position.position.maxScrollExtent);
              await settle(tester);
              await check(tester, '$label (scrolled)', c);
            }
          }
          handle.dispose();
        });
      }
    }
  }

  testWidgets('the splash, held on SHUFFLING', (tester) async {
    tester.view.physicalSize = sizes.first * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LoadingScreen.launch(
          steps: [
            LaunchStep('SHUFFLING', () => Completer<void>().future),
            LaunchStep('DEALING', () async {}),
            LaunchStep('READY', () async {}),
          ],
          onDone: () {},
        ),
      ),
    );
    await tester.pump();
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(find.text('SHUFFLING'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(const CheckedTextGuideline()));
    await expectLater(tester, meetsGuideline(RecordingTapTargetGuideline([])));
    handle.dispose();
    // The minimum-display and step-timeout timers run out.
    await tester.pump(const Duration(seconds: 6));
  });

  tearDownAll(() {
    // The exception is not silent: every tappable exempt kind was needed
    // somewhere above, and a kind nobody needed is a stale entry.
    for (final e in exemptKinds.entries) {
      if (e.value.tappable) {
        expect(
          kindsNeeded,
          contains(e.key),
          reason: 'exempt kind never flagged: ${e.key}',
        );
      } else {
        expect(
          kindsNeeded,
          isNot(contains(e.key)),
          reason: '${e.key} is listed as not tappable',
        );
      }
    }
  });
}
