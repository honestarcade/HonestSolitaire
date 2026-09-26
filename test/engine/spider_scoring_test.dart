import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import 'positions.dart';

void main() {
  test('the deal is 500 and every move costs one', () {
    final g = SpiderGame.deal(DealNumber(1));
    expect(g.score, SpiderScoring.atDeal);
    expect(g.score, 500);
    final moves = g.legalMoves();
    final next = applied(g, moves.first);
    expect(next.score, 499);
    expect(next.lastDelta, -1);
    expect(next.moves, 1);
    final dealt = applied(g, const DealRow());
    expect(dealt.score, 499);
    expect(dealt.moves, 1);
  });

  test('a completed run adds 100: net +99 with its move', () {
    final g = spider(
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
    );
    final next = applied(g, const MoveCards(1, 0, 0));
    expect(next.score, 599);
    expect(next.lastDelta, 99);
    expect(next.moves, 1, reason: 'the removal is not a move');
  });

  test('the move cost floors at 0 before the run bonus', () {
    final g = spider(
      tableau: [
        kingDown(Suit.spades, 2),
        cards('AS'),
        cards('3S'),
        [],
        [],
        [],
        [],
        [],
        [],
        [],
      ],
      moveScore: 0,
    );
    final plain = applied(g, const MoveCards(1, 0, 0));
    expect(
      plain.score,
      100,
      reason: 'a run completed from 0 gives 100, not 99',
    );
    final noRun = spider(
      tableau: [cards('4S'), cards('3S'), [], [], [], [], [], [], [], []],
      moveScore: 0,
    );
    expect(applied(noRun, const MoveCards(1, 0, 0)).score, 0);
    expect(applied(noRun, const MoveCards(1, 0, 0)).lastDelta, 0);
    final flipCost = spider(
      tableau: [cards('4S* 3S'), cards('4S'), [], [], [], [], [], [], [], []],
      options: const SpiderOptions(autoFlip: false),
      moveScore: 7,
    );
    var f = applied(flipCost, const MoveCards(0, 1, 1));
    expect(f.score, 6);
    f = applied(f, const Flip(0));
    expect(f.score, 5, reason: 'a manual flip costs one like any move');
    expect(f.moves, 2);
  });

  test('refusals leave the score and moves alone', () {
    final g = spider(
      tableau: [cards('4S'), cards('9S'), [], [], [], [], [], [], [], []],
    );
    expect(refused(g, const MoveCards(1, 0, 0)), RefusalReason.rankMismatch);
    expect(g.score, 500);
    expect(g.moves, 0);
  });

  group('the clock and the win bonus', () {
    SpiderGame nearWin(SpiderOptions options, Duration elapsed) => spider(
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
      options: options,
      moveScore: 1200,
      elapsed: elapsed,
    );

    test('tick accumulates in timed and untimed games alike', () {
      var g = SpiderGame.deal(DealNumber(1), const SpiderOptions(timed: false));
      g = g.tick(const Duration(seconds: 7));
      g = applied(g, const DealRow());
      g = g.tick(const Duration(seconds: 8));
      expect(g.elapsed, const Duration(seconds: 15));
      expect(g.score, 499, reason: 'Spider has no per-second penalty');
      expect(() => g.tick(const Duration(seconds: -1)), throwsArgumentError);
    });

    test(
      'a timed win at 120 s adds 5,833; the winning lastDelta excludes it',
      () {
        final won = applied(
          nearWin(const SpiderOptions(), const Duration(seconds: 120)),
          const MoveCards(1, 0, 0),
        );
        expect(won.isWon, isTrue);
        expect(won.timeBonus, 5833);
        expect(won.score, 1200 - 1 + 100 + 5833);
        expect(won.lastDelta, 99);
        expect(
          won.tick(const Duration(seconds: 100)).elapsed,
          const Duration(seconds: 120),
        );
      },
    );

    test('a win at 10 s counts as 30 s: 23,333', () {
      final won = applied(
        nearWin(const SpiderOptions(), const Duration(seconds: 10)),
        const MoveCards(1, 0, 0),
      );
      expect(won.timeBonus, 23333);
    });

    test('an untimed win adds nothing', () {
      final won = applied(
        nearWin(const SpiderOptions(timed: false), const Duration(seconds: 10)),
        const MoveCards(1, 0, 0),
      );
      expect(won.isWon, isTrue);
      expect(won.timeBonus, 0);
      expect(won.score, 1299);
    });
  });

  test('the constants are the planned ones', () {
    expect(SpiderScoring.atDeal, 500);
    expect(SpiderScoring.perMove, -1);
    expect(SpiderScoring.perRun, 100);
    expect(SpiderScoring.floor, 0);
    expect(timeBonusNumerator, 700000);
    expect(minimumBonusSeconds, 30);
  });
}
