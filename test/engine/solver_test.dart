import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/solver.dart';

import 'positions.dart';

KlondikeGame replay(KlondikeGame game, List<Move> moves) {
  var g = game;
  for (final move in moves) {
    g = applied(g, move);
  }
  return g;
}

void main() {
  test('a won game is Solved with no moves; a bad budget throws', () {
    final g = klondike(
      tableau: [cards('KC'), [], [], [], [], [], []],
      foundations: [
        suitRun(Suit.spades, 13),
        suitRun(Suit.hearts, 13),
        suitRun(Suit.diamonds, 13),
        suitRun(Suit.clubs, 12),
      ],
    );
    final won = applied(g, const TableauToFoundation(0));
    expect(solve(won), isA<Solved>());
    expect((solve(won) as Solved).moves, isEmpty);
    expect(() => solve(g, nodeBudget: 0), throwsArgumentError);
    expect(() => solve(g, nodeBudget: -3), throwsArgumentError);
  });

  test('a near-won deal is Solved and the line replays to isWon', () {
    final g = klondike(
      tableau: [
        cards('KC QD JC'),
        cards('KH QS'),
        cards('10D'),
        cards('KS'),
        cards('KD'),
        cards('QC'),
        [],
      ],
      waste: cards('9C'),
      stock: cards('JD* 10C* 9D*'),
      foundations: [
        suitRun(Suit.spades, 11),
        suitRun(Suit.hearts, 12),
        suitRun(Suit.diamonds, 8),
        suitRun(Suit.clubs, 8),
      ],
    );
    final result = solve(g);
    expect(result, isA<Solved>(), reason: '$result');
    final solved = result as Solved;
    expect(solved.moves, isNotEmpty);
    final end = replay(g, solved.moves);
    expect(end.isWon, isTrue);
    for (final move in solved.moves) {
      expect(move, isA<KlondikeMove>());
    }
  });

  test('with auto-flip off the line carries the flips', () {
    final g = klondike(
      tableau: [cards('QC* KD'), cards('KC QD JC'), [], [], [], [], []],
      foundations: [
        suitRun(Suit.spades, 13),
        suitRun(Suit.hearts, 13),
        suitRun(Suit.diamonds, 11),
        suitRun(Suit.clubs, 10),
      ],
      options: const KlondikeOptions(autoFlip: false),
    );
    final result = solve(g) as Solved;
    expect(result.moves.whereType<Flip>(), isNotEmpty);
    expect(replay(g, result.moves).isWon, isTrue);
  });

  test('a dead position is Unsolvable', () {
    // Four kings and three eights each sit on the very cards they would
    // need; no column is empty and there is no stock. Nothing can move
    // except a six off a foundation, which lands nowhere.
    final g = klondike(
      tableau: [
        cards('QD* KS'),
        cards('QC* KH'),
        cards('QH* KD'),
        cards('9C* KC'),
        cards('9H* 8S'),
        cards('9S* 8H'),
        cards('9D* 8C'),
      ],
      foundations: [
        suitRun(Suit.spades, 6),
        suitRun(Suit.hearts, 6),
        suitRun(Suit.diamonds, 6),
        suitRun(Suit.clubs, 6),
      ],
      dump: 0,
    );
    final result = solve(g);
    expect(result, isA<Unsolvable>(), reason: '$result');
    expect((result as Unsolvable).nodesUsed, lessThan(50));
  });

  test('a budget of one on a fresh deal is Unknown', () {
    final result = solve(KlondikeGame.deal(DealNumber(1)), nodeBudget: 1);
    expect(result, isA<Unknown>());
    expect((result as Unknown).nodesUsed, 2);
  });

  test('the same inputs give the same result twice', () {
    for (final seed in [1, 2, 3]) {
      final g = KlondikeGame.deal(DealNumber(seed));
      final a = solve(g, nodeBudget: 5000);
      final b = solve(g, nodeBudget: 5000);
      expect(a.runtimeType, b.runtimeType);
      if (a is Solved) {
        expect(a.moves, (b as Solved).moves);
        expect(a.nodesUsed, b.nodesUsed);
        expect(replay(g, a.moves).isWon, isTrue);
      } else if (a is Unknown) {
        expect(a.nodesUsed, (b as Unknown).nodesUsed);
      }
    }
  });

  test('solving from mid-game works and respects the draw mode', () {
    var g = KlondikeGame.deal(
      DealNumber(7),
      const KlondikeOptions(draw: DrawMode.three),
    );
    for (var i = 0; i < 5; i++) {
      g = applied(g, const Draw());
    }
    final result = solve(g);
    if (result is Solved) {
      expect(replay(g, result.moves).isWon, isTrue);
      expect(result.moves.whereType<Recycle>().length, lessThanOrEqualTo(60));
    } else {
      expect(result, isA<Unknown>());
    }
  });

  group('the floors', () {
    for (final (draw, floor) in [
      (DrawMode.one, 0.60),
      (DrawMode.three, 0.40),
    ]) {
      test(
        'draw ${draw.count}: ≥ ${(floor * 100).round()}% of seeds 1–200 solved, '
        'under 1 s each on average',
        () {
          var solved = 0;
          var unsolvable = 0;
          final watch = Stopwatch()..start();
          for (var seed = 1; seed <= 200; seed++) {
            final g = KlondikeGame.deal(
              DealNumber(seed),
              KlondikeOptions(draw: draw),
            );
            final result = solve(g);
            if (result is Solved) {
              solved++;
              expect(
                replay(g, result.moves).isWon,
                isTrue,
                reason: 'seed $seed',
              );
            } else if (result is Unsolvable) {
              unsolvable++;
            }
          }
          watch.stop();
          final rate = solved / 200;
          final mean = watch.elapsedMilliseconds / 200;
          printOnFailure(
            'draw ${draw.count}: $solved solved, $unsolvable unsolvable, '
            'mean ${mean.toStringAsFixed(0)} ms',
          );
          // ignore: avoid_print
          print(
            'solver draw ${draw.count}: $solved/200 solved, $unsolvable unsolvable, '
            'mean ${mean.toStringAsFixed(0)} ms per deal',
          );
          expect(rate, greaterThanOrEqualTo(floor));
          expect(mean, lessThan(1000));
        },
        tags: ['slow'],
        timeout: const Timeout(Duration(minutes: 10)),
      );
    }
  });
}
