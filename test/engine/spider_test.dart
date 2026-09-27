import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/rng.dart';

import 'positions.dart';

void main() {
  group('deal', () {
    for (final suits in SpiderSuits.values) {
      test(
        '${suits.count} suit(s): 6,6,6,6,5×6 columns, tops up, five rows',
        () {
          final game = SpiderGame.deal(
            DealNumber(1),
            SpiderOptions(suits: suits),
          );
          for (var c = 0; c < 10; c++) {
            expect(game.tableau[c], hasLength(c < 4 ? 6 : 5));
            for (var i = 0; i < game.tableau[c].length - 1; i++) {
              expect(game.tableau[c][i].faceUp, isFalse);
            }
            expect(game.tableau[c].last.faceUp, isTrue);
          }
          expect(game.stock, hasLength(5));
          expect(game.rowsLeft, 5);
          for (final row in game.stock) {
            expect(row, hasLength(10));
            expect(row.every((x) => !x.faceUp), isTrue);
          }
          final all = [
            for (final col in game.tableau) ...col,
            for (final row in game.stock) ...row,
          ].map((x) => x.down.toJson()).toList()..sort();
          final expected = spiderDeck(suits).map((x) => x.toJson()).toList()
            ..sort();
          expect(all, expected);
          expect(game.completed, isEmpty);
          expect(game.score, 500);
          expect(game.moves, 0);
          expect(game.isWon, isFalse);
        },
      );
    }

    test('the same number deals the same game and lists cannot be changed', () {
      final a = SpiderGame.deal(DealNumber(9));
      expect(a, SpiderGame.deal(DealNumber(9)));
      expect(a, isNot(SpiderGame.deal(DealNumber(10))));
      expect(() => a.tableau[0].add(c('AS')), throwsUnsupportedError);
      expect(() => a.stock.removeLast(), throwsUnsupportedError);
      expect(() => a.stock[0].clear(), throwsUnsupportedError);
    });
  });

  group('moves', () {
    test('a single card moves onto any suit one rank higher', () {
      final game = spider(
        tableau: [
          cards('7H'),
          cards('8S'),
          cards('8H'),
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.four),
      );
      final next = applied(game, const MoveCards(0, 0, 1));
      expect(next.tableau[1], cards('8S 7H'));
      expect(next.tableau[0], isEmpty);
      expect(next.moves, 1);
      expect(game.tableau[1], cards('8S'));
    });

    test('a mixed-suit group is refused; a same-suit run moves', () {
      final game = spider(
        tableau: [
          cards('9S 8H 7H'),
          cards('10S'),
          cards('9D'),
          cards('KC* 8D'),
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.four),
      );
      expect(
        refused(game, const MoveCards(0, 0, 1)),
        RefusalReason.notSameSuitRun,
      );
      final next = applied(game, const MoveCards(0, 1, 2));
      expect(next.tableau[2], cards('9D 8H 7H'));
      expect(next.tableau[0], cards('9S'));
      expect(
        refused(game, const MoveCards(0, 2, 1)),
        RefusalReason.rankMismatch,
      );
      expect(refused(game, const MoveCards(3, 0, 1)), RefusalReason.notFaceUp);
      expect(
        refused(game, const MoveCards(2, 0, 3)),
        RefusalReason.rankMismatch,
      );
      expect(
        refused(game, const MoveCards(0, 0, 0)),
        RefusalReason.invalidMove,
      );
      expect(
        refused(game, const MoveCards(0, 3, 1)),
        RefusalReason.invalidMove,
      );
      expect(
        refused(game, const MoveCards(10, 0, 1)),
        RefusalReason.invalidMove,
      );
      expect(refused(game, const Draw()), RefusalReason.invalidMove);
    });

    test('an empty column takes any card or valid run', () {
      final game = spider(
        tableau: [cards('3S 2S'), cards('QH'), [], [], [], [], [], [], [], []],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final run = applied(game, const MoveCards(0, 0, 2));
      expect(run.tableau[2], cards('3S 2S'));
      final single = applied(game, const MoveCards(1, 0, 3));
      expect(single.tableau[3], cards('QH'));
    });

    test('auto-flip on turns the uncovered card; off leaves it until Flip', () {
      final on = spider(
        tableau: [cards('KH* 5S'), cards('6S'), [], [], [], [], [], [], [], []],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      expect(applied(on, const MoveCards(0, 1, 1)).tableau[0], cards('KH'));
      expect(refused(on, const Flip(0)), RefusalReason.flipNotAllowed);

      final off = spider(
        tableau: [
          cards('KH* 5S'),
          cards('6S'),
          cards('QS'),
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.two, autoFlip: false),
      );
      final moved = applied(off, const MoveCards(0, 1, 1));
      expect(moved.tableau[0], cards('KH*'));
      expect(refused(moved, const MoveCards(2, 0, 0)), RefusalReason.notFaceUp);
      expect(moved.legalMoves().first, const Flip(0));
      final flipped = applied(moved, const Flip(0));
      expect(flipped.tableau[0], cards('KH'));
      expect(flipped.moves, 2);
      expect(refused(flipped, const Flip(0)), RefusalReason.flipNotAllowed);
      expect(refused(flipped, const Flip(3)), RefusalReason.flipNotAllowed);
      expect(refused(flipped, const Flip(10)), RefusalReason.invalidMove);
    });
  });

  group('dealing rows', () {
    test('a row puts one face-up card on every column, first row first', () {
      final game = SpiderGame.deal(DealNumber(3));
      final row = game.stock.first;
      final next = applied(game, const DealRow());
      for (var c = 0; c < 10; c++) {
        expect(next.tableau[c].last, row[c].up);
        expect(next.tableau[c], hasLength(game.tableau[c].length + 1));
      }
      expect(next.rowsLeft, 4);
      expect(next.stock, game.stock.sublist(1));
    });

    test('strict refuses a deal with an empty column; relaxed allows it', () {
      final strict = spider(
        tableau: [cards('7H'), [], [], [], [], [], [], [], [], []],
        stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      expect(strict.canDealRow, isFalse);
      expect(refused(strict, const DealRow()), RefusalReason.emptyColumnStrict);
      expect(strict.legalMoves(), isNot(contains(const DealRow())));

      final relaxed = spider(
        tableau: [cards('7H'), [], [], [], [], [], [], [], [], []],
        stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        options: const SpiderOptions(suits: SpiderSuits.two, relaxed: true),
      );
      expect(relaxed.canDealRow, isTrue);
      final next = applied(relaxed, const DealRow());
      expect(next.tableau[1], cards('2S'));
      expect(next.tableau[0], cards('7H AS'));
      expect(refused(next, const DealRow()), RefusalReason.stockEmpty);
    });

    test('dealing is allowed over a face-down top when auto-flip is off', () {
      final game = spider(
        tableau: [
          cards('KH*'),
          cards('QS'),
          cards('QS'),
          cards('QS'),
          cards('QS'),
          cards('QH'),
          cards('QH'),
          cards('QH'),
          cards('JH'),
          cards('JH'),
        ],
        stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        options: const SpiderOptions(suits: SpiderSuits.two, autoFlip: false),
      );
      final next = applied(game, const DealRow());
      expect(next.tableau[0], cards('KH* AS'));
    });
  });

  group('completed runs', () {
    test('the run leaves the board and the exposed card turns up', () {
      final game = spider(
        tableau: [
          [c('5H*'), ...kingDown(Suit.spades, 2)],
          cards('AS'),
          cards('4H'),
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final result =
          game.apply(const MoveCards(1, 0, 0)) as Applied<SpiderGame>;
      final next = result.game;
      expect(next.tableau[0], cards('5H'));
      expect(next.tableau[1], isEmpty);
      expect(next.completed, [Suit.spades]);
      expect(next.runsCompleted, 1);
      expect(result.effects.runsCompleted, [Suit.spades]);
      expect(result.effects.cardsFlipped, 1);
      expect(next.score, 500 - 1 + 100);
    });

    test('with auto-flip off the exposed card stays down until Flip', () {
      final game = spider(
        tableau: [
          [c('5H*'), ...kingDown(Suit.spades, 2)],
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
        options: const SpiderOptions(suits: SpiderSuits.two, autoFlip: false),
      );
      final next = applied(game, const MoveCards(1, 0, 0));
      expect(next.tableau[0], cards('5H*'));
      expect(next.completed, [Suit.spades]);
      expect(applied(next, const Flip(0)).tableau[0], cards('5H'));
    });

    test('a run with a face-down card in it is not complete', () {
      final game = spider(
        tableau: [
          [c('KS*'), ...kingDown(Suit.spades, 2).skip(1)],
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
      final next = applied(game, const MoveCards(1, 0, 0));
      expect(next.completed, isEmpty);
      expect(next.tableau[0], hasLength(13));
    });

    test('a dealt row completing two runs removes both', () {
      final game = spider(
        tableau: [
          kingDown(Suit.spades, 2),
          kingDown(Suit.spades, 2),
          cards('QS'),
          cards('QS'),
          cards('QS'),
          cards('QS'),
          cards('QS'),
          cards('QS'),
          cards('JS'),
          cards('JS'),
        ],
        stock: [cards('AS AS 3S 3S 3S 3S 3S 3S 4S 4S')],
      );
      final result = game.apply(const DealRow()) as Applied<SpiderGame>;
      expect(result.game.completed, [Suit.spades, Suit.spades]);
      expect(result.game.tableau[0], isEmpty);
      expect(result.game.tableau[1], isEmpty);
      expect(result.game.tableau[2], cards('QS 3S'));
      expect(result.effects.rowDealt, isTrue);
      expect(result.effects.runsCompleted, hasLength(2));
      expect(result.game.score, 500 - 1 + 200);
    });

    test('isWon at eight runs, not at seven', () {
      final seven = spider(
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
      );
      expect(seven.isWon, isFalse);
      final won = applied(seven, const MoveCards(1, 0, 0));
      expect(won.isWon, isTrue);
      expect(won.completed, hasLength(8));
      expect(won.tableau.every((col) => col.isEmpty), isTrue);
      expect(won.legalMoves(), isEmpty);
      expect(refused(won, const DealRow()), RefusalReason.gameOver);
    });
  });

  group('legalMoves', () {
    test('lists flips, every run start onto every taker, then the deal', () {
      final game = spider(
        tableau: [
          cards('9S 8S'),
          cards('10H'),
          cards('9H'),
          cards('KH*'),
          cards('2S'),
          cards('2S'),
          cards('2S'),
          cards('2S'),
          cards('2H'),
          cards('2H'),
        ],
        stock: [cards('AS AS AS AS AH AH AH AH 3S 3S')],
        options: const SpiderOptions(suits: SpiderSuits.two, autoFlip: false),
      );
      expect(game.legalMoves(), [
        const Flip(3),
        const MoveCards(0, 0, 1),
        const MoveCards(0, 1, 2),
        const MoveCards(2, 0, 1),
        const DealRow(),
      ]);
    });

    test('every legal move applies, over seeded playouts per suit count', () {
      for (final suits in SpiderSuits.values) {
        for (var seed = 1; seed <= 20; seed++) {
          var game = SpiderGame.deal(
            DealNumber(seed),
            SpiderOptions(suits: suits),
          );
          final rng = Rng(seed);
          for (var step = 0; step < 40; step++) {
            final moves = game.legalMoves();
            if (moves.isEmpty) break;
            for (final move in moves) {
              expect(
                game.apply(move),
                isA<Applied<SpiderGame>>(),
                reason: '$move on\n$game',
              );
            }
            game = applied(game, moves[rng.nextInt(moves.length)]);
          }
        }
      }
    });
  });

  group('fromPiles', () {
    test(
      'refuses a wrong deck, a face-down card on a face-up one, a short row',
      () {
        expect(
          () => SpiderGame.fromPiles(
            tableau: [cards('AS'), ...List.generate(9, (_) => <Card>[])],
          ),
          throwsArgumentError,
        );
        expect(
          () => spider(
            tableau: [cards('AS 2S*'), [], [], [], [], [], [], [], [], []],
            dump: 5,
          ),
          throwsArgumentError,
        );
        expect(
          () => spider(
            tableau: [[], [], [], [], [], [], [], [], [], []],
            stock: [cards('AS 2S')],
          ),
          throwsArgumentError,
        );
        expect(
          () => spider(
            tableau: [cards('AH'), [], [], [], [], [], [], [], [], []],
          ),
          throwsArgumentError,
        );
      },
    );
  });

  test('options default to one suit, strict, auto-flip, timed', () {
    const options = SpiderOptions();
    expect(options.suits, SpiderSuits.one);
    expect(options.relaxed, isFalse);
    expect(options.autoFlip, isTrue);
    expect(options.timed, isTrue);
    expect(options.toJson(), {
      'suits': 1,
      'relaxed': false,
      'autoFlip': true,
      'timed': true,
    });
  });
}
