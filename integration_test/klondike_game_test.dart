// A whole Klondike game on a device, by taps (#112): deal by number, play,
// undo, background, a real force-stop between phases (tools/e2e.sh), Continue
// restores the exact board, FINISH wins, Statistics counts it once, and the
// menu offers no Continue afterwards (#152). Then the complements: a refused
// move changes nothing, and the dead-end banner appears only at a dead end.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart';
import 'package:honest_solitaire/engine/solver.dart';
import 'package:honest_solitaire/ui/game/game_event.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

const options = KlondikeOptions(draw: DrawMode.one, timed: false);

/// The first deal from 1000 the solver proves at its default budget.
(DealNumber, List<Move>) solvableDeal() {
  for (var n = 1000; n < 1200; n++) {
    final deal = DealNumber(n);
    if (solve(KlondikeGame.deal(deal, options)) case Solved(:final moves)) {
      return (deal, moves);
    }
  }
  fail('e2e: no solvable Klondike deal in 1000–1199');
}

/// The first deal from 1000 whose hint-following play reaches a position
/// with no useful move, and the moves that reach it.
(DealNumber, List<Move>) deadEndDeal() {
  for (var n = 1000; n < 1500; n++) {
    final deal = DealNumber(n);
    Game g = KlondikeGame.deal(deal, options);
    final moves = <Move>[];
    for (var i = 0; i < 300 && !g.isWon; i++) {
      final h = hint(g);
      if (h is NoMovesLeft) return (deal, moves);
      final m = (h as MoveHint).move;
      moves.add(m);
      g = after(g, m);
    }
  }
  fail('e2e: no dead-end Klondike deal in 1000–1499');
}

Game replay(DealNumber deal, Iterable<Move> moves) =>
    moves.fold<Game>(KlondikeGame.deal(deal, options), after);

Future<void> startKlondike(WidgetTester t, DealNumber deal) async {
  await tapKey(t, 'menu-klondike');
  await tapKey(t, 'ksetup-draw-one');
  await tapKey(t, 'ksetup-scoring-standard');
  await tapKey(t, 'ksetup-timed-off');
  await tapKey(t, 'ksetup-deal-random');
  await typeDealNumber(t, deal);
  await tapKey(t, 'ksetup-deal');
  await waitFor(t, find.byKey(const Key('board-title')), seconds: 60);
  await wait(t, 500);
  expect(
    state(scope(t).controller.game),
    state(KlondikeGame.deal(deal, options)),
    reason: 'e2e: the board is not deal ${deal.value} as chosen',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final (deal, solution) = solvableDeal();

  testWidgets('Klondike, phase $e2ePhase', (t) async {
    await launch(t);
    final c = scope(t).controller;
    final four = replay(deal, solution.take(4));
    final five = replay(deal, solution.take(5));

    if (e2ePhase == 1) {
      await configure(t);
      await startKlondike(t, deal);
      for (final m in solution.take(5)) {
        await playMove(t, m);
      }

      // A refused move changes nothing, on the board or in the save.
      final k = c.game as KlondikeGame;
      final from = k.tableau.indexWhere((col) => col.isNotEmpty);
      final to = [for (var i = 0; i < k.tableau.length; i++) i].firstWhere(
        (i) =>
            i != from &&
            k.tableau[i].isNotEmpty &&
            !k.legalMoves().contains(
              MoveRun(from, k.tableau[from].length - 1, i),
            ),
      );
      await wait(t, 700);
      final savedBefore = await savedState(t, GameType.klondike);
      final boardBefore = state(c.game);
      await wait(t, 350);
      await tapCard(t, 't$from', k.tableau[from].length - 1);
      await tapColumn(t, k.tableau[to], to);
      await wait(t, 700);
      expect(
        state(c.game),
        boardBefore,
        reason: 'e2e: a refused move changed the board',
      );
      expect(
        await savedState(t, GameType.klondike),
        savedBefore,
        reason: 'e2e: a refused move changed the save',
      );
      await clearSelection(t);

      // HINT on a live position rings a move and raises no banner.
      await tapKey(t, 'tool-hint');
      expect(c.currentHint, isNotNull, reason: 'e2e: HINT showed nothing');
      expect(
        c.currentHint!.noMoves,
        isFalse,
        reason: 'e2e: a live deal read as dead',
      );
      expect(find.byKey(const Key('no-moves-banner')), findsNothing);
      await tapKey(t, 'tool-hint');
      expect(
        c.currentHint,
        isNull,
        reason: 'e2e: a second HINT did not hide it',
      );

      // Undo, then the same move again at once and straight into the
      // background: the replay is still inside its save window, so only the
      // flush on backgrounding can save it.
      await wait(t, 700);
      await tapAt(t, t.getCenter(find.byKey(const Key('tool-undo'))));
      expect(state(c.game), state(four), reason: 'e2e: undo took back move 5');
      await playMove(t, solution[4], settle: false);
      phaseOneDone(await background(t, saved: GameType.klondike));
      return;
    }

    // Phase 2: a cold start after a force-stop.
    expect(
      resumeLabel(t),
      'Continue Klondike',
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
    await playMove(t, solution[4]);

    // The rest of the solution until the board can finish, then FINISH:
    // the sweep route that #152 found skipping the win's bookkeeping.
    for (final m in solution.skip(5)) {
      if (c.canFinish) break;
      await playMove(t, m);
    }
    expect(
      c.canFinish,
      isTrue,
      reason: 'e2e: the solution never reached FINISH',
    );
    await tapKey(t, 'tool-finish');
    await waitFor(t, find.byKey(const Key('win-card')), seconds: 60);
    await scope(t).statsListener.lastRecord;
    final total = scope(t).stats.document.klondike.total;
    expect(
      [total.played, total.won, total.streak],
      [1, 1, 1],
      reason: 'e2e: Statistics did not count the win exactly once',
    );
    await tapKey(t, 'win-stats');
    await waitFor(t, find.byKey(const Key('stats-back')));
    await wait(t, 500);
    expect(
      [
        textOf(t, 'stats-value-played'),
        textOf(t, 'stats-sub-winrate'),
        textOf(t, 'stats-value-streak'),
      ],
      ['1', '1 won', '1'],
      reason: 'e2e: the Statistics screen does not show the win',
    );
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

    // Run last: at a real dead end, HINT raises the banner.
    final (deadDeal, toDeadEnd) = deadEndDeal();
    await startKlondike(t, deadDeal);
    for (final m in toDeadEnd) {
      await playMove(t, m);
    }
    await wait(t, 350);
    await tapKey(t, 'tool-hint');
    await waitFor(t, find.byKey(const Key('no-moves-banner')));
  });
}
