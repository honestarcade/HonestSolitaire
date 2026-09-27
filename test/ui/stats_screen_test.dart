import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/stats.dart';
import 'package:honest_solitaire/ui/format.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';
import 'package:honest_solitaire/ui/widgets/game_tabs.dart';

import 'setup_helpers.dart';

/// The design's sample numbers, as a document.
const seeded = StatsDocument(
  klondike: GameStats(
    total: TotalStats(
      played: 184,
      won: 97,
      streak: 4,
      playMs: (11 * 60 + 20) * 60000 + 30000,
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
  spider: GameStats(
    total: TotalStats(
      played: 126,
      won: 41,
      streak: 2,
      playMs: (14 * 60 + 3) * 60000,
      bestTimeMs: 485000,
      fewestMoves: 96,
      highScore: 1180,
    ),
    modes: {
      'one': ModeStats(played: 34, won: 28),
      'two': ModeStats(played: 51, won: 11),
      'four': ModeStats(played: 41, won: 2),
    },
  ),
);

Future<AppStore> storeWith(StatsDocument doc) async {
  final store = AppStore.memory();
  await store.write(StoreDoc.stats, doc.toJson());
  return store;
}

String value(WidgetTester tester, String name) =>
    tester.widget<Text>(find.byKey(Key('stats-value-$name'))).data!;
String sub(WidgetTester tester, String name) =>
    tester.widget<Text>(find.byKey(Key('stats-sub-$name'))).data!;

String rowValue(WidgetTester tester, String mode) {
  final row = find.byKey(Key('stats-row-$mode'));
  final texts = find
      .descendant(of: row, matching: find.byType(Text))
      .evaluate()
      .map((e) => (e.widget as Text).data!)
      .toList();
  return texts.last;
}

void main() {
  test('formatPlayTime and formatPercent', () {
    expect(formatPlayTime((11 * 60 + 20) * 60000 + 59000), '11h 20m');
    expect(formatPlayTime(5 * 60000), '0h 05m');
    expect(formatPlayTime(1234 * 3600000 + 5 * 60000), '1,234h 05m');
    expect(formatPercent(26, 88), '30%');
    expect(formatPercent(2, 41), '5%');
  });

  testWidgets(
    'a seeded document shows every card and row; tabs switch content',
    (tester) async {
      await openScreen(
        tester,
        const StatsScreen(),
        store: await storeWith(seeded),
      );
      expect(find.text('Statistics'), findsOneWidget);
      expect(
        tester.widget<GameTabs>(find.byType(GameTabs)).selected,
        GameType.klondike,
      );
      expect(value(tester, 'played'), '184');
      expect(sub(tester, 'played'), 'Since install');
      expect(value(tester, 'winrate'), '53%');
      expect(sub(tester, 'winrate'), '97 won');
      expect(value(tester, 'besttime'), '3:42');
      expect(sub(tester, 'besttime'), 'Fastest finish');
      expect(value(tester, 'fewest'), '118');
      expect(sub(tester, 'fewest'), 'In a won game');
      expect(value(tester, 'streak'), '4');
      expect(sub(tester, 'streak'), 'Consecutive wins');
      expect(value(tester, 'highscore'), '2,410');
      expect(sub(tester, 'highscore'), 'Total play 11h 20m');
      expect(find.text('BY DRAW MODE'), findsOneWidget);
      expect(rowValue(tester, 'draw1'), '71 / 96 · 74%');
      expect(rowValue(tester, 'draw3'), '26 / 88 · 30%');
      expect(rowValue(tester, 'vegas'), '+\$430 lifetime');
      expect(
        find.bySemanticsLabel('Draw three, 26 won of 88, 30 percent'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Games played, 184, Since install'),
        findsOneWidget,
      );
      await tapKey(tester, 'stats-tab-spider');
      expect(find.text('BY SUIT COUNT'), findsOneWidget);
      expect(value(tester, 'played'), '126');
      expect(value(tester, 'winrate'), '33%');
      expect(value(tester, 'besttime'), '8:05');
      expect(sub(tester, 'highscore'), 'Total play 14h 03m');
      expect(rowValue(tester, 'one'), '28 / 34 · 82%');
      expect(rowValue(tester, 'two'), '11 / 51 · 22%');
      expect(rowValue(tester, 'four'), '2 / 41 · 5%');
      expect(find.byKey(const Key('stats-row-vegas')), findsNothing);
    },
  );

  testWidgets(
    'empty stats show "—" everywhere and Reset is disabled; a negative Vegas total shows minus dollars',
    (tester) async {
      await openScreen(tester, const StatsScreen());
      for (final name in [
        'played',
        'winrate',
        'besttime',
        'fewest',
        'streak',
        'highscore',
      ]) {
        expect(value(tester, name), '—', reason: name);
      }
      expect(sub(tester, 'winrate'), '— won');
      expect(sub(tester, 'highscore'), 'Total play —');
      expect(rowValue(tester, 'draw1'), '0 / 0 · —');
      expect(rowValue(tester, 'vegas'), '—');
      await tapKey(tester, 'stats-reset');
      expect(
        find.byKey(const Key('stats-confirm')),
        findsNothing,
        reason: 'disabled when both games are empty',
      );
      final store = await storeWith(
        const StatsDocument(
          klondike: GameStats(
            total: TotalStats(played: 3),
            vegas: VegasStats(played: 3, won: 0, dollars: -120),
          ),
        ),
      );
      await openScreen(tester, const StatsScreen(), store: store);
      expect(rowValue(tester, 'vegas'), '−\$120 lifetime');
      expect(
        value(tester, 'winrate'),
        '0%',
        reason: 'played > 0 shows real zeros',
      );
      expect(sub(tester, 'winrate'), '0 won');
      expect(value(tester, 'streak'), '0');
    },
  );

  testWidgets(
    'Cancel leaves the document; Reset clears both games and the confirm copy is the corrected one',
    (tester) async {
      final scope = await openScreen(
        tester,
        const StatsScreen(),
        store: await storeWith(seeded),
      );
      await tapKey(tester, 'stats-reset');
      expect(find.byKey(const Key('stats-confirm')), findsOneWidget);
      expect(find.text('Reset statistics?'), findsOneWidget);
      expect(find.text(resetConfirmText), findsOneWidget);
      expect(resetConfirmText, contains('no other copy'));
      expect(resetConfirmText, isNot(contains('only copy')));
      await tapKey(tester, 'stats-confirm-cancel');
      expect(find.byKey(const Key('stats-confirm')), findsNothing);
      expect(value(tester, 'played'), '184');
      expect(scope.stats.document.klondike.total.played, 184);
      // Back acts as Cancel.
      await tapKey(tester, 'stats-reset');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byKey(const Key('stats-confirm')), findsNothing);
      expect(find.byType(StatsScreen), findsOneWidget);
      await tapKey(tester, 'stats-reset');
      await tapKey(tester, 'stats-confirm-reset');
      expect(find.byKey(const Key('stats-confirm')), findsNothing);
      expect(value(tester, 'played'), '—');
      expect(rowValue(tester, 'draw1'), '0 / 0 · —');
      await tapKey(tester, 'stats-tab-spider');
      expect(
        value(tester, 'played'),
        '—',
        reason: 'the other game is cleared too',
      );
      expect(scope.stats.document, StatsDocument.empty);
      await tester.pump(const Duration(seconds: 1));
      await scope.store.flush();
      final saved = (await scope.store.read(StoreDoc.stats) as Loaded).data;
      expect(StatsDocument.fromJson(saved).klondike.total.played, 0);
    },
  );

  testWidgets(
    'focus returns to Reset after Cancel or Reset dismiss the confirmation (#142)',
    (tester) async {
      await openScreen(
        tester,
        const StatsScreen(),
        store: await storeWith(seeded),
      );
      FocusNode resetFocus() => tester
          .widget<Focus>(
            find.byWidgetPredicate(
              (w) => w is Focus && w.focusNode?.debugLabel == 'stats-reset',
            ),
          )
          .focusNode!;

      await tapKey(tester, 'stats-reset');
      await tapKey(tester, 'stats-confirm-cancel');
      await tester.pump();
      expect(
        resetFocus().hasFocus,
        isTrue,
        reason: 'Cancel returns focus to Reset',
      );

      await tapKey(tester, 'stats-reset');
      await tapKey(tester, 'stats-confirm-reset');
      await tester.pump();
      expect(
        resetFocus().hasFocus,
        isTrue,
        reason: 'Reset returns focus to itself',
      );
    },
  );

  testWidgets('opened with a Spider game it starts on Spider', (tester) async {
    await openScreen(
      tester,
      const StatsScreen(game: GameType.spider),
      store: await storeWith(seeded),
    );
    expect(
      tester.widget<GameTabs>(find.byType(GameTabs)).selected,
      GameType.spider,
    );
    expect(find.text('BY SUIT COUNT'), findsOneWidget);
  });
}
