import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart';
import 'package:honest_solitaire/engine/rng.dart';

import 'positions.dart';

const two = SpiderOptions(suits: SpiderSuits.two);
const four = SpiderOptions(suits: SpiderSuits.four);

/// A Spider tableau from the columns a test names: the given columns, then
/// single kings (which go nowhere) up to nine, then an all-face-down tenth
/// column that takes the rest of the deck, so a position has no accidental
/// moves. Kings cycle through the suits in play.
List<List<Card>> tab(
  List<List<Card>> given, {
  SpiderSuits suits = SpiderSuits.one,
}) {
  final out = List<List<Card>>.of(given);
  var k = 0;
  while (out.length < 9) {
    out.add([Card(13, suits.suits[k % suits.count], faceUp: true)]);
    k++;
  }
  out.add([]);
  return out;
}

void main() {
  group('Klondike hint priorities', () {
    test('a foundation move comes first, waste before tableau', () {
      final g = klondike(
        tableau: [cards('AS'), cards('9H* 8S'), cards('9D'), [], [], [], []],
        waste: cards('AH'),
      );
      expect(hint(g), const MoveHint(WasteToFoundation()));
      final tableauOnly = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), cards('AS'), [], [], [], []],
        waste: cards('5C'),
      );
      expect(hint(tableauOnly), const MoveHint(TableauToFoundation(2)));
    });

    test('with auto-flip off a flip ranks right after foundation moves', () {
      final g = klondike(
        tableau: [cards('9H*'), cards('9D 8S'), cards('AS'), [], [], [], []],
        options: const KlondikeOptions(autoFlip: false),
      );
      expect(hint(g), const MoveHint(TableauToFoundation(2)));
      final noFoundation = klondike(
        tableau: [cards('9H*'), cards('9D 8S'), cards('7H'), [], [], [], []],
        options: const KlondikeOptions(autoFlip: false),
      );
      expect(hint(noFoundation), const MoveHint(Flip(0)));
    });

    test('a move that turns up a card beats waste to tableau', () {
      final g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), cards('6H'), [], [], [], []],
        waste: cards('5C'),
      );
      expect(hint(g), const MoveHint(MoveRun(0, 1, 1)));
    });

    test('among turn-ups, the column with the most face-down cards wins', () {
      final g = klondike(
        tableau: [
          cards('9H* 8D'),
          cards('KH* QC* 8S'),
          cards('9D'),
          cards('9C'),
          [],
          [],
          [],
        ],
      );
      expect(hint(g), const MoveHint(MoveRun(1, 2, 2)));
    });

    test('waste to tableau beats emptying a column and the stock', () {
      final g = klondike(
        tableau: [cards('QD'), cards('KS'), cards('6H'), [], [], [], []],
        waste: cards('5C'),
        stock: cards('4H*'),
      );
      expect(hint(g), const MoveHint(WasteToTableau(2)));
    });

    test(
      'emptying a column ranks above the stock, higher with a king waiting',
      () {
        final g = klondike(
          tableau: [
            cards('QD'),
            cards('KS'),
            cards('2S'),
            cards('KH'),
            cards('KD'),
            cards('2H'),
            [],
          ],
          waste: cards('KC'),
          stock: cards('4H*'),
        );
        expect(hint(g), const MoveHint(MoveRun(0, 0, 1)));
        final noKing = klondike(
          tableau: [
            cards('QD'),
            cards('KS'),
            cards('2S'),
            cards('KH'),
            cards('KD'),
            cards('2H'),
            [],
          ],
          waste: cards('5C'),
          stock: cards('4H*'),
        );
        expect(hint(noKing), const MoveHint(MoveRun(0, 0, 1)));
      },
    );

    test('a run already on a valid parent is not shuffled sideways', () {
      final g = klondike(
        tableau: [cards('9D 8S'), cards('9H'), [], [], [], [], []],
        stock: cards('7H*'),
      );
      expect(g.legalMoves(), contains(const MoveRun(0, 1, 1)));
      expect(hint(g), const MoveHint(Draw()));
    });

    test('moving it is useful when the card it exposes can go up', () {
      final g = klondike(
        tableau: [cards('AD 8S'), cards('9H'), [], [], [], [], []],
        stock: cards('7H*'),
        foundations: [[], [], [], []],
      );
      // AD is not a valid parent of 8S, but as a face-up exposed card that
      // can go to its foundation the move is hinted above the stock.
      expect(hint(g), const MoveHint(MoveRun(0, 1, 1)));
    });

    test('a whole column never goes to an empty column; a foundation card never comes back', () {
      final g = klondike(
        tableau: [cards('KS QD'), [], cards('3H'), [], [], [], []],
        foundations: [cards('AS 2S'), [], [], []],
        stock: cards('JC*'),
      );
      expect(g.legalMoves(), contains(const MoveRun(0, 0, 1)));
      expect(g.legalMoves(), contains(const FoundationToTableau(0, 2)));
      expect(hint(g), const MoveHint(Draw()));
    });

    test('drawing is hinted only when a pass can play a card; draw 3 offsets respected', () {
      // Stock bottom → top. With draw 3 the tops seen are 4♣ then 2♣ (the
      // remainder of two), and after a recycle the same again: the A♠ under
      // the 2♣ is never on top.
      final stock = cards('2C* AS* 4C* 5C* 6C*');
      final one = klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        stock: stock,
      );
      expect(hint(one), const MoveHint(Draw()));
      expect(stockCanHelp(one), isTrue);
      final three = klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        stock: stock,
        options: const KlondikeOptions(draw: DrawMode.three),
      );
      expect(stockCanHelp(three), isFalse);
      expect(hint(three), const NoMovesLeft());
      expect(three.legalMoves(), contains(const Draw()));
    });

    test('recycle is hinted when the waste holds the playable card', () {
      final g = klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        waste: cards('AS 7C 8C'),
      );
      expect(hint(g), const MoveHint(Recycle()));
      final hopeless = klondike(
        tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
        waste: cards('9C 7C 8C'),
      );
      expect(hint(hopeless), const NoMovesLeft());
    });

    test('a won game has no moves left', () {
      final g = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 12),
        ],
      );
      expect(
        hint(applied(g, const TableauToFoundation(0))),
        const NoMovesLeft(),
      );
    });
  });

  group('Klondike bestDestination', () {
    test('foundation first, else the first accepting column, never empty for a whole column', () {
      final g = klondike(
        tableau: [
          cards('KS QD'),
          [],
          cards('7H'),
          cards('7D'),
          cards('9C 8D'),
          [],
          [],
        ],
        waste: cards('6S'),
        foundations: [cards('AS'), [], [], []],
      );
      expect(
        bestDestination(g, const PileRef.waste()),
        const WasteToTableau(2),
      );
      expect(bestDestination(g, const PileRef.tableau(0, 0)), isNull);
      expect(bestDestination(g, const PileRef.tableau(0, 1)), isNull);
      expect(bestDestination(g, const PileRef.tableau(4, 1)), isNull);
      expect(bestDestination(g, const PileRef.foundation(0)), isNull);
      expect(bestDestination(g, const PileRef.stock()), isNull);
      final withTwo = klondike(
        tableau: [cards('KH* 8S'), cards('9D'), cards('9H'), [], [], [], []],
        waste: cards('2S'),
        foundations: [cards('AS'), [], [], []],
      );
      expect(
        bestDestination(withTwo, const PileRef.waste()),
        const WasteToFoundation(),
      );
      expect(
        bestDestination(withTwo, const PileRef.tableau(0, 1)),
        const MoveRun(0, 1, 1),
      );
      expect(bestDestination(withTwo, const PileRef.tableau(0, 0)), isNull);
      expect(bestDestination(withTwo, const PileRef.tableau(9, 0)), isNull);
      expect(bestDestination(withTwo, const PileRef.tableau(0, 5)), isNull);
    });
  });

  group('Spider hint priorities', () {
    test('a same-suit join comes first, even when a turn-up is available', () {
      final g = spider(
        tableau: tab([
          cards('5S'),
          cards('6S'),
          cards('9H* 4H'),
        ], suits: SpiderSuits.two),
        options: two,
      );
      expect(hint(g), const MoveHint(MoveCards(0, 0, 1)));
    });

    test('a move that turns up a card beats one into an empty column', () {
      final g = spider(
        tableau: tab([
          cards('9H* 4H'),
          cards('5S'),
          [],
          cards('JS 3S'),
        ], suits: SpiderSuits.two),
        options: two,
      );
      expect(hint(g), const MoveHint(MoveCards(0, 1, 1)));
    });

    test('an empty column is used when the move uncovers a card', () {
      final g = spider(
        tableau: tab([
          cards('9H* 4H'),
          [],
          cards('JS 3S'),
        ], suits: SpiderSuits.two),
        options: two,
      );
      expect(hint(g), const MoveHint(MoveCards(0, 1, 1)));
    });

    test(
      'a run on a same-suit parent is not moved to another same-suit parent',
      () {
        final g = spider(
          tableau: tab([cards('9S 8S'), cards('9S')]),
          stock: [cards('AS 2S 2S 2S 2S 3S 3S 3S 3S 4S')],
        );
        expect(g.legalMoves(), contains(const MoveCards(0, 1, 1)));
        expect(hint(g), const MoveHint(DealRow()));
        final noStock = spider(tableau: tab([cards('9S 8S'), cards('9S')]));
        expect(hint(noStock), const NoMovesLeft());
      },
    );

    test('a run on a different-suit parent upgrades to a same-suit one', () {
      final g = spider(
        tableau: tab([cards('9H 8S'), cards('9S')], suits: SpiderSuits.two),
        options: two,
      );
      expect(hint(g), const MoveHint(MoveCards(0, 1, 1)));
    });

    test('a whole column never goes to an empty column', () {
      final g = spider(tableau: tab([cards('7S 6S'), []]));
      expect(g.legalMoves(), contains(const MoveCards(0, 0, 1)));
      expect(hint(g), const NoMovesLeft());
      expect(bestDestination(g, const PileRef.tableau(0, 0)), isNull);
    });

    test('with auto-flip off a flip comes first', () {
      final g = spider(
        tableau: tab([cards('9S*'), cards('6S'), cards('5S')]),
        options: const SpiderOptions(autoFlip: false),
      );
      expect(hint(g), const MoveHint(Flip(0)));
    });

    test('strict rule with an empty column and stock: fill it with the smallest run', () {
      final g = spider(
        tableau: tab([cards('10S 9S 8S'), cards('JS 5S 4S'), []]),
        stock: [cards('2S 2S 2S 2S 3S 3S 3S 3S 6S 6S')],
      );
      expect(g.canDealRow, isFalse);
      expect(hint(g), const MoveHint(MoveCards(0, 2, 2)));
      final relaxed = SpiderGame.fromPiles(
        tableau: g.tableau,
        stock: g.stock,
        options: const SpiderOptions(relaxed: true),
      );
      expect(hint(relaxed), const MoveHint(DealRow()));
    });

    test('a turn-up fill is preferred to a smaller run', () {
      final g = spider(
        tableau: tab([cards('10S 9S 8S'), cards('JS* 5S 4S'), []]),
        stock: [cards('2S 2S 2S 2S 3S 3S 3S 3S 6S 6S')],
      );
      expect(hint(g), const MoveHint(MoveCards(1, 1, 2)));
    });

    test('when every fill would empty its own column: no moves left', () {
      final g = spider(
        tableau: tab([cards('7S'), cards('4S'), []]),
        stock: [cards('2S 2S 2S 2S 3S 3S 3S 3S 6S 6S')],
      );
      expect(hint(g), const NoMovesLeft());
    });
  });

  group('Spider bestDestination', () {
    test('same suit, then any suit, then an empty column; never off a same-suit parent to another suit', () {
      final g = spider(
        tableau: [
          cards('5H'),
          cards('6S'),
          cards('6H'),
          [],
          cards('7S 6S 5S'),
          cards('7H 6S'),
          cards('KS'),
          cards('KS'),
          cards('KH'),
          [],
        ],
        options: two,
      );
      expect(
        bestDestination(g, const PileRef.tableau(0, 0)),
        const MoveCards(0, 0, 2),
      );
      expect(
        bestDestination(g, const PileRef.tableau(4, 2)),
        const MoveCards(4, 2, 1),
      );
      // 6♠ 5♠ sits on a same-suit 7♠: it may go to an empty column, never
      // onto the different-suit 7♥.
      expect(
        bestDestination(g, const PileRef.tableau(4, 1)),
        const MoveCards(4, 1, 3),
      );
      // The 6♠ on the 7♥ has no same-suit parent free (the 7♠ is covered)
      // and no other any-suit parent, so the empty column.
      expect(
        bestDestination(g, const PileRef.tableau(5, 1)),
        const MoveCards(5, 1, 3),
      );
      expect(bestDestination(g, const PileRef.tableau(4, 0)), isNull);
      expect(bestDestination(g, const PileRef.tableau(4, 5)), isNull);
      expect(bestDestination(g, const PileRef.waste()), isNull);
      expect(bestDestination(g, const PileRef.foundation(0)), isNull);
      final faceDown = spider(tableau: tab([cards('9S* 5S'), cards('6S')]));
      expect(bestDestination(faceDown, const PileRef.tableau(0, 0)), isNull);
      expect(
        bestDestination(faceDown, const PileRef.tableau(0, 1)),
        const MoveCards(0, 1, 1),
      );
    });
  });

  test('every hint over seeded random positions is legal and applies', () {
    var positions = 0;
    var hints = 0;
    final variants = <Game Function(int)>[
      (s) => KlondikeGame.deal(DealNumber(s)),
      (s) => KlondikeGame.deal(
        DealNumber(s),
        const KlondikeOptions(draw: DrawMode.three),
      ),
      (s) => SpiderGame.deal(DealNumber(s)),
      (s) => SpiderGame.deal(DealNumber(s), two),
      (s) => SpiderGame.deal(DealNumber(s), four),
    ];
    for (final variant in variants) {
      for (var seed = 1; seed <= 20; seed++) {
        var game = variant(seed);
        final rng = Rng(seed);
        for (var step = 0; step < 30; step++) {
          positions++;
          final legal = game.legalMoves();
          final h = hint(game);
          if (h is MoveHint) {
            hints++;
            expect(legal, contains(h.move), reason: '${h.move} on\n$game');
            expect(
              game.apply(h.move),
              isA<Applied>(),
              reason: '${h.move} on\n$game',
            );
          }
          // Every source's best destination applies too.
          for (var c = 0; c < (game is KlondikeGame ? 7 : 10); c++) {
            final column = game is KlondikeGame
                ? game.tableau[c]
                : (game as SpiderGame).tableau[c];
            for (var i = 0; i < column.length; i++) {
              final dest = bestDestination(game, PileRef.tableau(c, i));
              if (dest != null) {
                expect(
                  game.apply(dest),
                  isA<Applied>(),
                  reason: '$dest on\n$game',
                );
              }
            }
          }
          if (game is KlondikeGame) {
            final dest = bestDestination(game, const PileRef.waste());
            if (dest != null) expect(game.apply(dest), isA<Applied>());
          }
          if (legal.isEmpty || game.isWon) break;
          game = applied(game, legal[rng.nextInt(legal.length)]);
        }
      }
    }
    expect(positions, greaterThanOrEqualTo(500));
    expect(hints, greaterThan(positions ~/ 2));
  });
}
