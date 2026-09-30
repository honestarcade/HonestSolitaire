// A whole Spider game on a device, by taps (#112): deal by number, play,
// undo, background, a real force-stop between phases (tools/e2e.sh), Continue
// restores the exact board, the line plays to the win, Statistics counts it
// once, and the menu offers no Continue afterwards. The complement: a strict
// deal refused over an empty column changes nothing, on the board or on disk.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';
import 'support/spider_search.dart';

const options = SpiderOptions(suits: SpiderSuits.one, timed: false);

Game replay(DealNumber deal, Iterable<Move> moves) =>
    moves.fold<Game>(SpiderGame.deal(deal, options), after);

/// Whether a strict deal is refused at [g]: a column is empty, rows are
/// left, and the engine does not offer the deal.
bool dealRefused(SpiderGame g) =>
    g.rowsLeft > 0 &&
    g.tableau.any((c) => c.isEmpty) &&
    !g.legalMoves().any((m) => m is DealRow);

Future<void> startSpider(WidgetTester t, DealNumber deal) async {
  await tapKey(t, 'menu-spider');
  await tapKey(t, 'ssetup-suits-one');
  await tapKey(t, 'ssetup-timed-off');
  await tapKey(t, 'ssetup-rule-strict');
  await typeDealNumber(t, deal);
  await tapKey(t, 'ssetup-deal');
  await waitFor(t, find.byKey(const Key('board-title')), seconds: 60);
  await wait(t, 500);
  expect(
    state(scope(t).controller.game),
    state(SpiderGame.deal(deal, options)),
    reason: 'e2e: the board is not deal ${deal.value} as chosen',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final (deal, line) = winnableSpiderDeal(options);

  testWidgets('Spider, phase $e2ePhase', (t) async {
    await launch(t);
    final c = scope(t).controller;
    final four = replay(deal, line.take(4));
    final five = replay(deal, line.take(5));

    if (e2ePhase == 1) {
      await configure(t);
      await startSpider(t, deal);
      for (final m in line.take(5)) {
        await playMove(t, m);
      }
      await tapKey(t, 'tool-undo');
      expect(state(c.game), state(four), reason: 'e2e: undo took back move 5');
      await playMove(t, line[4]);
      phaseOneDone(await background(t));
      return;
    }

    // Phase 2: a cold start after a force-stop.
    expect(
      resumeLabel(t),
      'Continue Spider',
      reason: 'e2e: nothing to continue',
    );
    await tapKey(t, 'menu-resume');
    await waitFor(t, find.byKey(const Key('board-title')));
    await wait(t, 500);
    expect(
      state(c.game),
      state(five),
      reason: 'e2e: Continue did not restore the board',
    );
    if (e2eElapsedMs >= 0) {
      expect(
        c.game.elapsed.inMilliseconds,
        inInclusiveRange(e2eElapsedMs, e2eElapsedMs + 1000),
        reason: 'e2e: the restored clock drifted',
      );
    }
    expect(c.isPaused, isFalse, reason: 'e2e: Continue left the game paused');
    await tapKey(t, 'tool-undo');
    expect(state(c.game), state(four), reason: 'e2e: undo after restore');
    await playMove(t, line[4]);

    var refusalChecked = false;
    for (final m in line.skip(5)) {
      if (!refusalChecked && dealRefused(c.game as SpiderGame)) {
        // Strict Spider refuses a deal onto an empty column: the board and
        // the saved slot are unchanged.
        await wait(t, 700);
        final savedBefore = scope(t).saves.value.spider!.game.toJson();
        final boardBefore = state(c.game);
        await wait(t, 350);
        await tapAt(t, rectOfKey(t, 'stock-sliver-0').center);
        await wait(t, 700);
        expect(
          state(c.game),
          boardBefore,
          reason: 'e2e: a refused deal changed the board',
        );
        expect(
          scope(t).saves.value.spider!.game.toJson(),
          savedBefore,
          reason: 'e2e: a refused deal changed the save',
        );
        refusalChecked = true;
      }
      await playMove(t, m);
    }
    expect(
      refusalChecked,
      isTrue,
      reason: 'e2e: the line never met a refused deal',
    );
    expect(c.game.isWon, isTrue, reason: 'e2e: the line did not win');
    await waitFor(t, find.byKey(const Key('win-card')), seconds: 60);
    await scope(t).statsListener.lastRecord;
    final total = scope(t).stats.document.spider.total;
    expect(
      [total.played, total.won, total.streak],
      [1, 1, 1],
      reason: 'e2e: Statistics did not count the win exactly once',
    );
    await tapKey(t, 'win-stats');
    await waitFor(t, find.byKey(const Key('stats-back')));
    await tapKey(t, 'stats-back');
    await waitFor(t, find.byKey(const Key('win-card')));
    await tapKey(t, 'win-menu');
    await waitFor(t, find.byKey(const Key('menu-resume')));
    await wait(t, 700);
    expect(
      resumeLabel(t),
      'New game',
      reason: 'e2e: a won game is still offered to Continue',
    );
  });
}
