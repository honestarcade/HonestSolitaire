import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import 'positions.dart';

const standard = KlondikeOptions(timed: false);
const vegas = KlondikeOptions(scoring: ScoringMode.vegas, timed: false);
const none = KlondikeOptions(scoring: ScoringMode.none, timed: false);

/// A position with one of everything scoreable: a waste card that can go to
/// the tableau or (after one move) its foundation, a covered card to flip,
/// a foundation card to take back, and an empty stock so a recycle is legal.
KlondikeGame scoreable(KlondikeOptions options, {int? moveScore}) => klondike(
  tableau: [cards('9H* 8S'), cards('AS'), cards('3S'), [], [], [], []],
  waste: cards('AH 7D'),
  foundations: [[], [], cards('AD 2D'), []],
  options: options,
  moveScore: moveScore,
);

void main() {
  group('standard', () {
    test('+10 to a foundation from the tableau and from the waste', () {
      var g = scoreable(standard);
      expect(g.score, 0);
      g = applied(g, const TableauToFoundation(1));
      expect(g.score, 10);
      expect(g.lastDelta, 10);
      g = applied(g, const WasteToTableau(0));
      g = applied(g, const WasteToFoundation());
      expect(g.score, 25);
      expect(g.lastDelta, 10);
    });

    test('a tableau-to-tableau move scores 0 and a flip it causes +5', () {
      var g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
        options: standard,
      );
      g = applied(g, const MoveRun(0, 1, 1));
      expect(g.score, 5, reason: 'only the auto-flip scores');
      expect(g.lastDelta, 5);
      final noFlip = klondike(
        tableau: [cards('8S'), cards('9D'), [], [], [], [], []],
        options: standard,
      );
      expect(applied(noFlip, const MoveRun(0, 0, 1)).score, 0);
    });

    test('+5 for a manual flip with auto-flip off', () {
      var g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
        options: standard.copyWith(autoFlip: false),
      );
      g = applied(g, const MoveRun(0, 1, 1));
      expect(g.score, 0);
      g = applied(g, const Flip(0));
      expect(g.score, 5);
      expect(g.moves, 2);
    });

    test('−15 for taking a card back off a foundation', () {
      var g = scoreable(standard, moveScore: 20);
      g = applied(g, const FoundationToTableau(2, 2));
      expect(g.score, 5);
      expect(g.lastDelta, -15);
    });

    test('−2 per recycle, floored at 0', () {
      var g = scoreable(standard, moveScore: 3);
      g = applied(g, const Recycle());
      expect(g.score, 1);
      expect(g.lastDelta, -2);
      g = applied(g, const Draw());
      g = applied(g, const Draw());
      g = applied(g, const Recycle());
      expect(g.score, 0, reason: 'the floor holds');
      expect(g.lastDelta, -1);
      g = applied(g, const Draw());
      g = applied(g, const Draw());
      expect(applied(g, const Recycle()).score, 0);
      expect(applied(g, const Recycle()).lastDelta, 0);
    });

    test('a draw scores 0', () {
      var g = scoreable(standard);
      g = applied(g, const Recycle());
      g = applied(g, const Draw());
      expect(g.lastDelta, 0);
    });
  });

  group('vegas', () {
    test('−52 at the deal, +5 per foundation card', () {
      var g = KlondikeGame.deal(DealNumber(1), vegas);
      expect(g.score, -52);
      g = scoreable(vegas);
      expect(g.score, -52);
      g = applied(g, const TableauToFoundation(1));
      expect(g.score, -47);
      expect(g.lastDelta, 5);
      g = applied(g, const WasteToTableau(0));
      g = applied(g, const WasteToFoundation());
      expect(g.score, -42);
    });

    test('taking a card back costs 5 and can go below the deal score', () {
      var g = klondike(
        tableau: [cards('3S'), [], [], [], [], [], []],
        foundations: [[], cards('AH 2H'), [], []],
        options: vegas,
      );
      g = applied(g, const FoundationToTableau(1, 0));
      expect(g.score, -57);
      expect(g.lastDelta, -5);
    });

    test('waste to tableau, flips and recycles score 0', () {
      var g = scoreable(vegas);
      g = applied(g, const WasteToTableau(0));
      expect(g.score, -52);
      g = applied(g, const Recycle());
      expect(g.score, -52);
      final flip = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
        options: vegas,
      );
      expect(applied(flip, const MoveRun(0, 1, 1)).score, -52);
    });
  });

  group('none', () {
    test('the score stays 0 through a sequence and the mode is exposed', () {
      var g = scoreable(none);
      expect(g.scoring, ScoringMode.none);
      expect(g.score, 0);
      g = applied(g, const TableauToFoundation(1));
      g = applied(g, const WasteToTableau(0));
      g = applied(g, const Recycle());
      g = applied(g, const FoundationToTableau(2, 2));
      expect(g.score, 0);
      expect(g.lastDelta, 0);
      expect(g.moves, 4);
    });
  });

  group('moves', () {
    test('refusals and auto-flips count 0', () {
      var g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
        waste: cards('AH'),
        options: standard,
      );
      expect(g.moves, 0);
      expect(refused(g, const MoveRun(1, 0, 0)), RefusalReason.rankMismatch);
      expect(g.moves, 0);
      g = applied(g, const MoveRun(0, 1, 1));
      expect(g.moves, 1, reason: 'the auto-flip is not a move');
      g = applied(g, const WasteToFoundation());
      expect(g.moves, 2);
    });

    test('draws, recycles and manual flips count; nothing else does', () {
      var g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
        stock: cards('AC*'),
        options: standard.copyWith(autoFlip: false),
      );
      g = applied(g, const Draw());
      expect(g.moves, 1);
      g = applied(g, const WasteToFoundation());
      expect(g.moves, 2);
      g = applied(g, const MoveRun(0, 1, 1));
      expect(g.moves, 3);
      expect(refused(g, const Draw()), RefusalReason.stockEmpty);
      expect(g.moves, 3);
      g = applied(g, const Flip(0));
      expect(g.moves, 4);
    });
  });

  group('the clock', () {
    test(
      'tick adds to elapsed; apply preserves it; a negative tick throws',
      () {
        var g = KlondikeGame.deal(DealNumber(1), standard);
        expect(g.elapsed, Duration.zero);
        g = g.tick(const Duration(seconds: 3));
        g = g.tick(const Duration(milliseconds: 500));
        expect(g.elapsed, const Duration(milliseconds: 3500));
        g = applied(g, const Draw());
        expect(g.elapsed, const Duration(milliseconds: 3500));
        expect(g.lastDelta, 0);
        expect(() => g.tick(const Duration(seconds: -1)), throwsArgumentError);
        expect(g.tick(Duration.zero).lastDelta, 0);
      },
    );

    test('timed standard: each full 10 s costs 2, never below 0', () {
      var g = scoreable(const KlondikeOptions(), moveScore: 20);
      g = g.tick(const Duration(seconds: 25));
      expect(g.score, 16);
      g = g.tick(const Duration(seconds: 4));
      expect(g.score, 16, reason: '29 s is still two full periods');
      g = g.tick(const Duration(seconds: 1));
      expect(g.score, 14);
      final low = scoreable(const KlondikeOptions(), moveScore: 2);
      expect(low.tick(const Duration(seconds: 25)).score, 0);
      expect(low.tick(const Duration(minutes: 30)).score, 0);
    });

    test('untimed standard and Vegas: ticking changes nothing', () {
      final untimed = scoreable(standard, moveScore: 20);
      expect(untimed.tick(const Duration(minutes: 5)).score, 20);
      final v = scoreable(const KlondikeOptions(scoring: ScoringMode.vegas));
      expect(v.tick(const Duration(minutes: 5)).score, -52);
    });

    test('undo never refunds the time penalty: it is tied to the clock', () {
      var g = scoreable(const KlondikeOptions(), moveScore: 20);
      g = applied(g, const TableauToFoundation(1));
      g = g.tick(const Duration(seconds: 30));
      expect(g.score, 30 - 6);
      final back = (g.undo(unlimited: true) as Applied<KlondikeGame>).game;
      expect(back.score, 20 - 6);
      expect(back.elapsed, const Duration(seconds: 30));
    });
  });

  group('the win bonus', () {
    KlondikeGame nearWin(KlondikeOptions options, Duration elapsed) => klondike(
      tableau: [cards('KC'), [], [], [], [], [], []],
      foundations: [
        suitRun(Suit.spades, 13),
        suitRun(Suit.hearts, 13),
        suitRun(Suit.diamonds, 13),
        suitRun(Suit.clubs, 12),
      ],
      options: options,
      moveScore: 100,
      elapsed: elapsed,
    );

    test('a timed standard win at 120 s adds 5,833', () {
      final g = nearWin(const KlondikeOptions(), const Duration(seconds: 120));
      expect(g.score, 100 - 24);
      final won = applied(g, const TableauToFoundation(0));
      expect(won.isWon, isTrue);
      expect(won.timeBonus, 5833);
      expect(won.score, 110 - 24 + 5833);
      expect(won.lastDelta, 10, reason: 'the bonus is not part of lastDelta');
      expect(won.tick(const Duration(seconds: 100)).score, won.score);
    });

    test('a win at 10 s counts as 30 s: 23,333', () {
      final g = nearWin(const KlondikeOptions(), const Duration(seconds: 10));
      expect(applied(g, const TableauToFoundation(0)).timeBonus, 23333);
      final g2 = nearWin(
        const KlondikeOptions(),
        const Duration(milliseconds: 30999),
      );
      expect(applied(g2, const TableauToFoundation(0)).timeBonus, 23333);
      final g3 = nearWin(
        const KlondikeOptions(),
        const Duration(milliseconds: 31000),
      );
      expect(applied(g3, const TableauToFoundation(0)).timeBonus, 22580);
    });

    test('untimed standard, Vegas and none add nothing', () {
      for (final options in [
        standard,
        vegas,
        const KlondikeOptions(scoring: ScoringMode.vegas),
        none,
        const KlondikeOptions(scoring: ScoringMode.none),
      ]) {
        final won = applied(
          nearWin(options, const Duration(seconds: 120)),
          const TableauToFoundation(0),
        );
        expect(won.isWon, isTrue);
        expect(won.timeBonus, 0, reason: '$options');
      }
      expect(
        applied(
          nearWin(vegas, const Duration(seconds: 120)),
          const TableauToFoundation(0),
        ).score,
        105,
      );
      expect(
        applied(
          nearWin(standard, const Duration(seconds: 120)),
          const TableauToFoundation(0),
        ).score,
        110,
      );
    });
  });

  group('the table', () {
    test('the engine scores from KlondikeScoring, mode by mode', () {
      for (final mode in ScoringMode.values) {
        final table = KlondikeScoring.of(mode);
        final options = KlondikeOptions(scoring: mode, timed: false);
        expect(
          KlondikeGame.deal(DealNumber(1), options).score,
          mode == ScoringMode.none ? 0 : table.delta(KlondikeScoreEvent.deal),
        );
        var g = scoreable(options, moveScore: 40);
        final start = g.score;
        final deltas = <KlondikeScoreEvent, int>{};
        deltas[KlondikeScoreEvent.toFoundation] =
            applied(g, const TableauToFoundation(1)).score - start;
        deltas[KlondikeScoreEvent.wasteToTableau] =
            applied(g, const WasteToTableau(0)).score - start;
        deltas[KlondikeScoreEvent.foundationToTableau] =
            applied(g, const FoundationToTableau(2, 2)).score - start;
        deltas[KlondikeScoreEvent.recycle] =
            applied(g, const Recycle()).score - start;
        g = klondike(
          tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
          options: options,
          moveScore: 40,
        );
        deltas[KlondikeScoreEvent.flip] =
            applied(g, const MoveRun(0, 1, 1)).score - g.score;
        for (final entry in deltas.entries) {
          expect(
            entry.value,
            mode == ScoringMode.none ? 0 : table.delta(entry.key),
            reason: '$mode ${entry.key}',
          );
        }
      }
      expect(KlondikeScoring.standard.floor, 0);
      expect(KlondikeScoring.vegas.floor, isNull);
      expect(KlondikeScoring.timePenaltyPoints, 2);
      expect(KlondikeScoring.timePenaltyPeriod, const Duration(seconds: 10));
      expect(timeBonusNumerator, 700000);
      expect(minimumBonusSeconds, 30);
    });
  });
}
