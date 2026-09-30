import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/game_saves.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:honest_solitaire/ui/screens/how_to_play_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';
import 'package:honest_solitaire/ui/widgets/game_tabs.dart';

import '../engine/positions.dart';
import 'setup_helpers.dart';

/// A store as a cold start finds it after a Spider game was played last.
Future<AppStore> spiderPlayedLast() async {
  final store = AppStore.memory();
  final saves = GameSaves(store);
  final spider = SpiderGame.deal(DealNumber(3));
  await saves.save(applied(spider, spider.legalMoves().first), start: true);
  return store;
}

GameType tabOf(WidgetTester tester) =>
    tester.widget<GameTabs>(find.byType(GameTabs)).selected;

void main() {
  for (final (name, screen) in [
    ('Statistics', const StatsScreen() as Widget),
    ('How to play', const HowToPlayScreen()),
  ]) {
    testWidgets(
      '$name after a cold start opens on the game played last (#166)',
      (tester) async {
        await openScreen(tester, screen, store: await spiderPlayedLast());
        expect(
          tabOf(tester),
          GameType.spider,
          reason: '$name ignored the last game played',
        );
      },
    );

    testWidgets('$name with nothing saved opens on Klondike (#166)', (
      tester,
    ) async {
      await openScreen(tester, screen);
      expect(tabOf(tester), GameType.klondike);
    });
  }
}
