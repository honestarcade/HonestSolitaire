import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/finish.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/rng.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import 'positions.dart';

/// Plays [moves] by hand through `apply`, asserting every step is legal.
KlondikeGame byHand(KlondikeGame game, List<Move> moves) {
  var g = game;
  for (final move in moves) {
    g = applied(g, move);
  }
  return g;
}

/// A random all-face-up board: foundations as per-suit prefixes, seven
/// legal alternating runs (any base card), and the rest split between
/// stock and waste — or forced entirely into one of them.
KlondikeGame generated(
  int seed,
  DrawMode draw, {
  bool emptyStock = false,
  bool emptyWaste = false,
}) {
  final rng = Rng(seed);
  final remaining = List<Card>.of(standardDeck());
  final foundations = <List<Card>>[];
  for (final suit in Suit.values) {
    final n = rng.nextInt(8);
    foundations.add(suitRun(suit, n));
    remaining.removeWhere((c) => c.suit == suit && c.rank <= n);
  }
  final tableau = <List<Card>>[];
  for (var c = 0; c < 7; c++) {
    final column = <Card>[];
    if (remaining.isNotEmpty && rng.nextInt(8) != 0) {
      var card = remaining.removeAt(rng.nextInt(remaining.length));
      column.add(card.up);
      while (rng.nextInt(3) != 0) {
        final next = remaining
            .where((x) => x.rank == card.rank - 1 && x.isRed != card.isRed)
            .toList();
        if (next.isEmpty) break;
        card = next[rng.nextInt(next.length)];
        remaining.remove(card);
        column.add(card.up);
      }
    }
    tableau.add(column);
  }
  final rest = shuffle(remaining, rng);
  final split = emptyStock
      ? rest.length
      : emptyWaste
      ? 0
      : rng.nextInt(rest.length + 1);
  return KlondikeGame.fromPiles(
    tableau: tableau,
    waste: rest.sublist(0, split),
    stock: [for (final c in rest.sublist(split)) c.down],
    foundations: foundations,
    options: KlondikeOptions(draw: draw),
    dealNumber: DealNumber(seed),
  );
}

void main() {
  group('fixtures', () {
    test(
      'an empty tableau finishes from the waste and stock in draw 1 and 3',
      () {
        // The stock is ordered so each triple's top is playable in turn, which
        // also serves draw 1; the waste plays straight from its top.
        for (final draw in DrawMode.values) {
          final g = klondike(
            tableau: [[], [], [], [], [], [], []],
            waste: cards('KC QC JC 10C 9C 8C 7C 6C 5C 4C 3C 2C AC'),
            stock: cards(
              'KD* 10D* JD* QD* 7D* 8D* 9D* 4D* 5D* 6D* AD* 2D* 3D*',
            ),
            foundations: [
              suitRun(Suit.spades, 13),
              suitRun(Suit.hearts, 13),
              [],
              [],
            ],
            options: KlondikeOptions(draw: draw),
          );
          expect(canFinish(g), isTrue, reason: '$draw');
          expect(
            isSolved(g),
            isFalse,
            reason: 'the stock and waste are not empty',
          );
          final moves = finishMoves(g);
          expect(moves, isNotEmpty);
          expect(moves.whereType<Draw>(), isNotEmpty);
          expect(byHand(g, moves).isWon, isTrue, reason: '$draw');
        }
      },
    );

    test(
      'an all-face-up tableau with an empty column and empty stock is solved',
      () {
        final g = klondike(
          tableau: [
            cards('KC QD JC 10D'),
            cards('KD QC JD 10C 9D 8C'),
            cards('9C 8D 7C 6D'),
            [],
            cards('7D 6C 5D 4C 3D 2C'),
            cards('5C 4D 3C 2D'),
            cards('AD AC'),
          ],
          foundations: [
            suitRun(Suit.spades, 13),
            suitRun(Suit.hearts, 13),
            [],
            [],
          ],
        );
        expect(isSolved(g), isTrue);
        expect(canFinish(g), isTrue);
        final result = applyFinish(g) as Applied<KlondikeGame>;
        expect(result.game.isWon, isTrue);
        expect(result.game.historyLength, 1, reason: 'one undo step');
        expect(result.effects.steps, hasLength(finishMoves(g).length));
        expect(result.game.moves, finishMoves(g).length);
        expect(result.game, byHand(g, finishMoves(g)));
        expect(result.game.score, byHand(g, finishMoves(g)).score);
        expect(result.game.historyMoves.single, isA<MoveGroup>());
        // A won game cannot be undone (#64); the single entry above is the
        // one-step record the sweep leaves.
      },
    );

    test('one face-down card: cannot finish, no moves, refused', () {
      final g = klondike(
        tableau: [cards('KD* AC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 12),
          [],
        ],
        dump: 1,
      );
      expect(g.allTableauFaceUp, isFalse);
      expect(canFinish(g), isFalse);
      expect(isSolved(g), isFalse);
      expect(finishMoves(g), isEmpty);
      expect((applyFinish(g) as Refused).reason, RefusalReason.cannotFinish);
    });

    test('one card left in the waste: can finish, not solved', () {
      final g = klondike(
        tableau: [cards('QC'), cards('KC'), [], [], [], [], []],
        waste: cards('KD'),
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 12),
          suitRun(Suit.clubs, 11),
        ],
      );
      expect(canFinish(g), isTrue);
      expect(isSolved(g), isFalse);
      expect(finishMoves(g), [
        const TableauToFoundation(0),
        const WasteToFoundation(),
        const TableauToFoundation(1),
      ]);
    });

    test('a won board can neither finish nor be solved', () {
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
      expect(canFinish(won), isFalse);
      expect(isSolved(won), isFalse);
      expect(finishMoves(won), isEmpty);
    });

    test('a stock the draw mode cannot unlock is honestly unfinishable', () {
      // Draw 3 over five cards sees only the 4♣ and 2♣ on top; the A♣ under
      // the 2♣ never surfaces, so nothing can start the clubs foundation.
      final stock = cards('2C* AC* 4C* 5C* 6C*');
      final three = klondike(
        tableau: [
          cards('KC QC JC 10C 9C 8C 7C'),
          cards('3C'),
          [],
          [],
          [],
          [],
          [],
        ],
        stock: stock,
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          [],
        ],
        options: const KlondikeOptions(draw: DrawMode.three),
      );
      expect(three.allTableauFaceUp, isTrue);
      expect(canFinish(three), isFalse);
      expect(finishMoves(three), isEmpty);
      final one = klondike(
        tableau: [
          cards('KC QC JC 10C 9C 8C 7C'),
          cards('3C'),
          [],
          [],
          [],
          [],
          [],
        ],
        stock: stock,
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          [],
        ],
      );
      expect(canFinish(one), isTrue);
      expect(byHand(one, finishMoves(one)).isWon, isTrue);
    });

    test('the sweep scores and counts exactly as by hand, in every mode', () {
      for (final scoring in ScoringMode.values) {
        final g = klondike(
          tableau: [
            cards('AC'),
            cards('2C'),
            cards('KC'),
            cards('QC'),
            cards('JC'),
            cards('10C'),
            cards('9C'),
          ],
          waste: cards('KD'),
          stock: cards('8C* 7C* 6C* 5C* 4C* 3C*'),
          foundations: [
            suitRun(Suit.spades, 13),
            suitRun(Suit.hearts, 13),
            suitRun(Suit.diamonds, 12),
            [],
          ],
          options: KlondikeOptions(scoring: scoring),
          moveScore: 50,
        );
        final moves = finishMoves(g);
        expect(moves, isNotEmpty, reason: '$scoring');
        final hand = byHand(g, moves);
        expect(hand.isWon, isTrue);
        final swept = (applyFinish(g) as Applied<KlondikeGame>).game;
        expect(swept.score, hand.score, reason: '$scoring');
        expect(swept.moves, hand.moves);
        expect(swept.timeBonus, hand.timeBonus);
        expect(swept, hand);
        expect(swept.historyLength, 1);
        expect(hand.historyLength, moves.length);
      }
    });
  });

  group('generated boards', () {
    for (final draw in DrawMode.values) {
      test(
        'seeds 1–200, draw ${draw.count}: canFinish agrees with finishMoves and every finish wins',
        () {
          var finishable = 0;
          for (var seed = 1; seed <= 200; seed++) {
            final g = generated(
              seed,
              draw,
              emptyStock: seed % 7 == 0,
              emptyWaste: seed % 11 == 0,
            );
            final moves = finishMoves(g);
            expect(canFinish(g), moves.isNotEmpty, reason: 'seed $seed');
            if (moves.isEmpty) continue;
            finishable++;
            final hand = byHand(g, moves);
            expect(hand.isWon, isTrue, reason: 'seed $seed');
            final swept = (applyFinish(g) as Applied<KlondikeGame>).game;
            expect(swept, hand);
            expect(swept.historyLength, 1);
            if (g.stock.isEmpty && g.waste.isEmpty) {
              expect(isSolved(g), isTrue);
            } else {
              expect(isSolved(g), isFalse);
            }
          }
          expect(
            finishable,
            greaterThan(draw == DrawMode.one ? 190 : 150),
            reason: 'the generator makes finishable boards',
          );
        },
      );
    }
  });
}
