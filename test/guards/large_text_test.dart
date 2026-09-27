@Tags(['guard', 'slow'])
library;

// Large text (#106): the phone's text size, clamped to 1.0–1.3×, reaches
// every screen; on a 320×568 phone at 1.3× nothing overflows, the board's
// bars keep their heights, card faces never scale, and above 1.3× nothing
// changes. Every AppRoute is pumped through the real app with its
// worst-case content, with the bundled fonts, so the measurements are real.

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
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/navigation.dart';
import 'package:honest_solitaire/ui/screens/about_app_screen.dart';
import 'package:honest_solitaire/ui/screens/about_studio_screen.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/screens/loading_screen.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';

import '../engine/positions.dart';
import '../helpers/fonts.dart';

/// A small phone: 320×568 at DPR 2.75, status bar 24, gesture bar 48.
const phone = Size(320, 568);
const dpr = 2.75;
const insets = FakeViewPadding(top: 24 * dpr, bottom: 48 * dpr);

/// The design's sample statistics: every card and row filled.
const fullStats = StatsDocument(
  klondike: GameStats(
    total: TotalStats(
      played: 1840,
      won: 970,
      streak: 14,
      playMs: (111 * 60 + 20) * 60000 + 30000,
      bestTimeMs: 222000,
      fewestMoves: 1118,
      highScore: 12410,
    ),
    modes: {
      'draw1': ModeStats(played: 960, won: 710),
      'draw3': ModeStats(played: 880, won: 260),
    },
    vegas: VegasStats(played: 120, won: 70, dollars: -4300),
  ),
  spider: GameStats(
    total: TotalStats(
      played: 1260,
      won: 410,
      streak: 12,
      playMs: (114 * 60 + 3) * 60000,
      bestTimeMs: 4850000,
      fewestMoves: 960,
      highScore: 11180,
    ),
    modes: {
      'suits1': ModeStats(played: 400, won: 200),
      'suits2': ModeStats(played: 400, won: 150),
      'suits4': ModeStats(played: 460, won: 60),
    },
  ),
);

/// Klondike, Vegas, in the red, an hour in, thousands of moves: the widest
/// readouts the top bar shows. Stuck, so HINT raises the banner.
final worstKlondike = klondike(
  tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
  waste: cards('9C 7C 8C'),
  options: const KlondikeOptions(
    draw: DrawMode.three,
    scoring: ScoringMode.vegas,
  ),
  moveScore: -52,
  moves: 1234,
  elapsed: const Duration(hours: 1, minutes: 23, seconds: 45),
  dealNumber: 999999,
);

/// Spider with every deal left (DEAL 5) and the same wide readouts.
final worstSpider = spider(
  tableau: [cards('KS'), cards('QS'), [], [], [], [], [], [], [], []],
  stock: [for (var i = 0; i < 5; i++) cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
  options: const SpiderOptions(suits: SpiderSuits.one),
  moves: 1234,
  elapsed: const Duration(hours: 1, minutes: 23, seconds: 45),
  dealNumber: 999999,
);

class _Dealer implements DealerHandle {
  final _events = StreamController<DealerEvent>();
  @override
  Stream<DealerEvent> get events => _events.stream;
  @override
  Future<void> cancel() async {}
}

/// A board state to show on top of a game.
enum BoardState { playing, paused, won, banner }

/// One case of the sweep: a screen, or the board in a state.
class Case {
  const Case(
    this.route, {
    this.state = BoardState.playing,
    this.spider = false,
    this.largeCards = false,
    this.leftHanded = false,
    this.confirming = false,
  });

  final AppRoute route;
  final BoardState state;
  final bool spider;
  final bool largeCards;
  final bool leftHanded;

  /// Statistics: the reset confirm open.
  final bool confirming;

  @override
  String toString() => [
    route.name,
    if (route == AppRoute.board) ...[
      spider ? 'spider' : 'klondike',
      state.name,
      if (largeCards) 'large-cards',
      if (leftHanded) 'left-handed',
    ],
    if (confirming) 'confirming',
  ].join(' ');
}

final cases = <Case>[
  for (final route in AppRoute.values)
    if (route == AppRoute.board)
      for (final spider in [false, true])
        for (final state in BoardState.values)
          for (final large in [false, true])
            for (final left in [false, true])
              Case(
                route,
                spider: spider,
                state: state,
                largeCards: large,
                leftHanded: left,
              )
    else if (route == AppRoute.stats) ...[
      Case(route),
      Case(route, confirming: true),
    ] else
      Case(route),
];

/// Pumps the app on [c] at [textScale] and settles it. The menu is the home
/// route; every other screen is pushed over it through the app's own route.
Future<GameScope> pumpCase(
  WidgetTester tester,
  Case c, {
  required double textScale,
}) async {
  tester.view.physicalSize = phone * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final store = AppStore.memory();
  await store.write(StoreDoc.stats, fullStats.toJson());
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: store,
      showSplash: false,
      search: (_, _) => _Dealer(),
      initialDisplayOptions: DisplayOptions(
        largeCards: c.largeCards,
        leftHanded: c.leftHanded,
        showTimer: true,
        showMovesAndScore: true,
      ),
      dealNumberSource: () => DealNumber(999999),
    ),
  );
  await tester.pump();
  await tester.pump();
  final scope = tester.widget<GameScope>(find.byType(GameScope));
  // The corruption banner, and a live game so Settings shows its notes.
  store.corruptionNotices.value = {StoreDoc.gameKlondike, StoreDoc.stats};
  scope.controller.replaceGame(c.spider ? worstSpider : worstKlondike);
  scope.controller.tapPile(const TableauPile(0), 0); // selects: a move begins
  scope.controller.tapPile(const TableauPile(0), 0);
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  switch (c.route) {
    case AppRoute.menu:
      break;
    case AppRoute.board:
      navigator.push(boardRoute());
    case AppRoute.newKlondike:
      navigator.push(
        FadePageRoute<void>(builder: (_) => const NewKlondikeScreen()),
      );
    case AppRoute.newSpider:
      navigator.push(
        FadePageRoute<void>(builder: (_) => const NewSpiderScreen()),
      );
    case AppRoute.loading:
      navigator.push(
        FadePageRoute<void>(
          builder: (_) => LoadingScreen.search(
            options: const KlondikeOptions(scoring: ScoringMode.vegas),
          ),
        ),
      );
    case AppRoute.settings:
      navigator.push(
        FadePageRoute<void>(builder: (_) => const SettingsScreen()),
      );
    case AppRoute.stats:
      navigator.push(FadePageRoute<void>(builder: (_) => const StatsScreen()));
    case AppRoute.howToPlay:
      navigator.push(
        FadePageRoute<void>(builder: (_) => const HowToPlayScreen()),
      );
    case AppRoute.aboutApp:
      navigator.push(
        FadePageRoute<void>(builder: (_) => const AboutAppScreen()),
      );
    case AppRoute.aboutStudio:
      navigator.push(
        FadePageRoute<void>(builder: (_) => const AboutStudioScreen()),
      );
  }
  await tester.pump();
  await tester.pump();
  if (c.route == AppRoute.board) {
    switch (c.state) {
      case BoardState.playing:
        break;
      case BoardState.paused:
        scope.controller.pause();
      case BoardState.banner:
        scope.controller.hint();
      case BoardState.won:
        scope.controller.replaceGame(
          c.spider
              ? spider(
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
                  options: const KlondikeOptions(scoring: ScoringMode.vegas),
                  moveScore: -52,
                  moves: 1234,
                  elapsed: const Duration(hours: 1, minutes: 23, seconds: 45),
                ),
        );
        await tester.pump();
        if (c.spider) {
          scope.controller.move(const TableauPile(1), 0, const TableauPile(0));
        } else {
          scope.controller.move(
            const TableauPile(0),
            0,
            const FoundationPile(Suit.clubs),
          );
        }
        // Animations are off (flutter_test_config): the card follows the
        // 250 ms delay with no cascade.
        await tester.pump(const Duration(milliseconds: 300));
    }
  }
  if (c.confirming) {
    await tester.ensureVisible(find.byKey(const Key('stats-reset')));
    await tester.tap(find.byKey(const Key('stats-reset')));
  }
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  return scope;
}

/// Every error the frame reported, drained.
List<Object> exceptions(WidgetTester tester) {
  final out = <Object>[];
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.add(e);
  }
  return out;
}

/// The keys whose text is allowed to ellipsize.
const ellipsisAllowed = {'board-title'};

/// Every paragraph on screen: its text, its scaled font size, whether it
/// overflowed its lines, whether a FittedBox holds it, and whether it is a
/// card face.
List<
  ({
    String text,
    double size,
    bool exceeded,
    bool fitted,
    bool card,
    bool allowedEllipsis,
  })
>
paragraphs(WidgetTester tester) {
  final out =
      <
        ({
          String text,
          double size,
          bool exceeded,
          bool fitted,
          bool card,
          bool allowedEllipsis,
        })
      >[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached) continue;
    final style = (element.widget as RichText).text.style;
    final fontSize = style?.fontSize;
    if (fontSize == null) continue;
    var fitted = false;
    var card = false;
    var allowed = false;
    element.visitAncestorElements((a) {
      final w = a.widget;
      if (w is FittedBox) fitted = true;
      if (w is PlayingCard) card = true;
      final k = w.key;
      if (k is ValueKey<String> && ellipsisAllowed.contains(k.value)) {
        allowed = true;
      }
      return true;
    });
    out.add((
      text: render.text.toPlainText(),
      size: render.textScaler.scale(fontSize),
      exceeded: render.didExceedMaxLines,
      fitted: fitted,
      card: card,
      allowedEllipsis: allowed,
    ));
  }
  return out;
}

Rect? rectOf(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) return null;
  return tester.getRect(finder.first);
}

void main() {
  setUpAll(loadAppFonts);

  for (final c in cases) {
    testWidgets('$c: fits at 1.3× on a small phone, 2.0× renders like 1.3×', (
      tester,
    ) async {
      // 1.0×: the reference.
      await pumpCase(tester, c, textScale: 1.0);
      expect(exceptions(tester), isEmpty, reason: '$c overflows at 1.0×');
      final base = paragraphs(tester);
      final topBar = rectOf(tester, const Key('pause-pill'));
      final toolRow = rectOf(tester, const Key('tool-new'));

      // 1.3×: everything fits; text is 1.3× or fitted; the bars hold.
      await pumpCase(tester, c, textScale: 1.3);
      final errors = exceptions(tester);
      expect(
        errors,
        isEmpty,
        reason: '$c overflows at 1.3×:\n${errors.map((e) => '$e').join('\n')}',
      );
      final large = paragraphs(tester);
      final scaler = MediaQuery.textScalerOf(
        tester.element(find.byType(GameScope)),
      );
      expect(
        scaler.scale(10),
        closeTo(13, 1e-9),
        reason: 'the clamp lets 1.3× through',
      );
      final exceeded = large.where((p) => p.exceeded && !p.allowedEllipsis);
      expect(
        exceeded,
        isEmpty,
        reason:
            '$c clips text at 1.3×: ${exceeded.map((p) => p.text).toList()}',
      );
      final cardSizes1 = base.where((p) => p.card).map((p) => p.size).toSet();
      final cardSizes13 = large.where((p) => p.card).map((p) => p.size).toSet();
      expect(cardSizes13, cardSizes1, reason: '$c: card faces never scale');
      if (c.route == AppRoute.board && c.state != BoardState.won) {
        final title = large.where((p) => p.allowedEllipsis);
        expect(title, isNotEmpty, reason: '$c: the board title is on screen');
        expect(
          title.any((p) => p.size > 11.5 * 320 / 390 * 1.2 || p.fitted),
          isTrue,
          reason: 'large-text-board: the top bar ignores the text size ($c)',
        );
        final pill = rectOf(tester, const Key('pause-pill'));
        final tool = rectOf(tester, const Key('tool-new'));
        expect(
          pill!.height,
          closeTo(topBar!.height, 0.5),
          reason: '$c: the top bar keeps its height',
        );
        expect(
          tool!.height,
          closeTo(toolRow!.height, 0.5),
          reason: '$c: the tool row keeps its height',
        );
        final screen = Offset.zero & phone;
        expect(
          screen.contains(pill.topLeft) && screen.contains(pill.bottomRight),
          isTrue,
          reason: '$c: the pill is on screen',
        );
        expect(
          screen.contains(tool.topLeft) && screen.contains(tool.bottomRight),
          isTrue,
          reason: '$c: the tool row is on screen',
        );
      }

      // 2.0×: exactly the 1.3× render.
      await pumpCase(tester, c, textScale: 2.0);
      expect(
        exceptions(tester),
        isEmpty,
        reason: 'large-text-clamp: $c overflows at 2.0× (the clamp is off)',
      );
      final huge = paragraphs(tester);
      expect(
        huge.map((p) => (p.text, p.size)).toList(),
        large.map((p) => (p.text, p.size)).toList(),
        reason: 'large-text-clamp: 2.0× renders differently from 1.3× ($c)',
      );

      // 0.85×: exactly the 1.0× render.
      await pumpCase(tester, c, textScale: 0.85);
      final small = paragraphs(tester);
      expect(
        small.map((p) => (p.text, p.size)).toList(),
        base.map((p) => (p.text, p.size)).toList(),
        reason: '$c: a small system scale renders like 1.0×',
      );
    });
  }
}
