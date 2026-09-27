import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import 'positions.dart';

void main() {
  group('deal', () {
    test('seven columns of 1..7, tops up, stock 24, all 52 distinct', () {
      final game = KlondikeGame.deal(DealNumber(1));
      for (var c = 0; c < 7; c++) {
        expect(game.tableau[c], hasLength(c + 1));
        for (var i = 0; i < c; i++) {
          expect(game.tableau[c][i].faceUp, isFalse);
        }
        expect(game.tableau[c].last.faceUp, isTrue);
      }
      expect(game.stock, hasLength(24));
      expect(game.stock.every((c) => !c.faceUp), isTrue);
      expect(game.waste, isEmpty);
      expect(game.foundations.every((f) => f.isEmpty), isTrue);
      final all = [
        for (final c in game.tableau) ...c,
        ...game.stock,
      ].map((c) => c.down).toSet();
      expect(all, hasLength(52));
      expect(game.moves, 0);
      expect(game.score, 0);
      expect(game.isWon, isFalse);
      expect(game.winnable, isFalse);
    });

    test(
      'the same number and options deal the same game; draw 3 same cards',
      () {
        final a = KlondikeGame.deal(DealNumber(77));
        final b = KlondikeGame.deal(DealNumber(77));
        expect(a, b);
        final three = KlondikeGame.deal(
          DealNumber(77),
          const KlondikeOptions(draw: DrawMode.three),
        );
        expect(three.tableau, a.tableau);
        expect(three.stock, a.stock);
        expect(three, isNot(a));
        expect(KlondikeGame.deal(DealNumber(78)).tableau, isNot(a.tableau));
      },
    );

    test('exposed lists cannot be changed', () {
      final game = KlondikeGame.deal(DealNumber(1));
      expect(() => game.tableau[0].add(c('AS')), throwsUnsupportedError);
      expect(() => game.stock.removeLast(), throwsUnsupportedError);
      expect(() => game.tableau.clear(), throwsUnsupportedError);
      expect(() => game.foundations[0].add(c('AS')), throwsUnsupportedError);
      final drawn = applied(game, const Draw());
      expect(() => drawn.waste.clear(), throwsUnsupportedError);
      expect(game.waste, isEmpty);
    });
  });

  group('tableau moves', () {
    test('a run moves onto an opposite-colour card one rank higher', () {
      final game = klondike(
        tableau: [cards('8H* 7S 6D'), cards('8D'), [], [], [], [], []],
      );
      final next = applied(game, const MoveRun(0, 1, 1));
      expect(next.tableau[1], cards('8D 7S 6D'));
      expect(next.tableau[0], cards('8H'));
      expect(next.moves, 1);
      expect(game.tableau[0], cards('8H* 7S 6D'));
    });

    test(
      'red on red, same rank, a colour break and a face-down card refuse',
      () {
        final game = klondike(
          tableau: [
            cards('8H* 7H 6D'),
            cards('7D'),
            cards('7S'),
            cards('6C'),
            [],
            [],
            [],
          ],
        );
        expect(
          refused(game, const MoveRun(0, 2, 1)),
          RefusalReason.colourMismatch,
        );
        expect(
          refused(game, const MoveRun(2, 0, 1)),
          RefusalReason.rankMismatch,
        );
        expect(
          refused(game, const MoveRun(0, 1, 1)),
          RefusalReason.notAlternatingRun,
        );
        expect(refused(game, const MoveRun(0, 0, 1)), RefusalReason.notFaceUp);
        expect(
          refused(game, const MoveRun(3, 0, 3)),
          RefusalReason.invalidMove,
        );
        expect(
          refused(game, const MoveRun(3, 5, 1)),
          RefusalReason.invalidMove,
        );
        expect(
          refused(game, const MoveRun(7, 0, 1)),
          RefusalReason.invalidMove,
        );
      },
    );

    test('only a king goes on an empty column', () {
      final game = klondike(
        tableau: [cards('QH'), cards('KS QD'), [], [], [], [], []],
      );
      expect(
        refused(game, const MoveRun(0, 0, 2)),
        RefusalReason.emptyColumnNeedsKing,
      );
      final next = applied(game, const MoveRun(1, 0, 2));
      expect(next.tableau[2], cards('KS QD'));
      expect(next.tableau[1], isEmpty);
    });

    test('a spider move or a move group is refused as invalid', () {
      final game = KlondikeGame.deal(DealNumber(1));
      expect(
        refused(game, const MoveCards(0, 0, 1)),
        RefusalReason.invalidMove,
      );
      expect(refused(game, const DealRow()), RefusalReason.invalidMove);
      expect(
        refused(game, const MoveGroup([Draw()])),
        RefusalReason.invalidMove,
      );
    });
  });

  group('waste and foundations', () {
    test('waste top goes to the tableau and to its foundation', () {
      final game = klondike(
        tableau: [cards('8S'), [], [], [], [], [], []],
        waste: cards('AH 7D'),
      );
      final onTableau = applied(game, const WasteToTableau(0));
      expect(onTableau.tableau[0], cards('8S 7D'));
      expect(onTableau.waste, cards('AH'));
      final onFoundation = applied(onTableau, const WasteToFoundation());
      expect(onFoundation.foundations[Suit.hearts.index], cards('AH'));
      expect(onFoundation.waste, isEmpty);
      expect(
        refused(onFoundation, const WasteToTableau(0)),
        RefusalReason.emptySource,
      );
      expect(
        refused(onFoundation, const WasteToFoundation()),
        RefusalReason.emptySource,
      );
    });

    test('a foundation takes only its suit, ace first then ascending', () {
      final game = klondike(
        tableau: [
          cards('2H'),
          cards('AS'),
          cards('2S'),
          cards('3S'),
          [],
          [],
          [],
        ],
        waste: cards('2D'),
      );
      // Hearts has no ace yet: the 2♥ has nowhere to go, even though spades
      // is about to have an ace — the suit picks the pile.
      expect(
        refused(game, const TableauToFoundation(0)),
        RefusalReason.foundationRankMismatch,
      );
      expect(
        refused(game, const WasteToFoundation()),
        RefusalReason.foundationRankMismatch,
      );
      var g = applied(game, const TableauToFoundation(1));
      expect(g.foundations[Suit.spades.index], cards('AS'));
      expect(
        refused(g, const TableauToFoundation(3)),
        RefusalReason.foundationRankMismatch,
      );
      g = applied(g, const TableauToFoundation(2));
      g = applied(g, const TableauToFoundation(3));
      expect(g.foundations[Suit.spades.index], cards('AS 2S 3S'));
    });

    test(
      'a foundation card comes back to the tableau; a face-down top stays',
      () {
        final game = klondike(
          tableau: [cards('3H'), cards('9C* 4S*'), [], [], [], [], []],
          foundations: [cards('AS 2S'), [], [], []],
        );
        final back = applied(game, const FoundationToTableau(0, 0));
        expect(back.tableau[0], cards('3H 2S'));
        expect(back.foundations[0], cards('AS'));
        expect(
          refused(game, const FoundationToTableau(1, 0)),
          RefusalReason.emptySource,
        );
        expect(
          refused(game, const FoundationToTableau(0, 1)),
          RefusalReason.notFaceUp,
        );
        expect(
          refused(game, const TableauToFoundation(1)),
          RefusalReason.notFaceUp,
        );
        expect(
          refused(game, const FoundationToTableau(4, 0)),
          RefusalReason.invalidMove,
        );
      },
    );
  });

  group('stock', () {
    test(
      'draw 1 turns one card; an empty stock with an empty waste refuses',
      () {
        final game = klondike(
          tableau: [cards('AS'), [], [], [], [], [], []],
          stock: cards('2H* 3H* 4H*'),
        );
        final one = applied(game, const Draw());
        expect(one.waste, cards('4H'));
        expect(one.stock, cards('2H* 3H*'));
        expect(one.lastDrawCount, 1);
        final empty = klondike(tableau: [cards('AS'), [], [], [], [], [], []]);
        expect(empty.stock, isEmpty);
        expect(refused(empty, const Draw()), RefusalReason.stockEmpty);
        expect(refused(empty, const Recycle()), RefusalReason.wasteEmpty);
      },
    );

    test(
      'draw 3 turns three, then the remainder, then refuses until recycled',
      () {
        final game = klondike(
          tableau: [cards('AS'), [], [], [], [], [], []],
          stock: cards('2H* 3H* 4H* 5H* 6H*'),
          options: const KlondikeOptions(draw: DrawMode.three),
        );
        final first = applied(game, const Draw());
        expect(first.waste, cards('6H 5H 4H'));
        expect(first.lastDrawCount, 3);
        expect(refused(first, const Recycle()), RefusalReason.stockNotEmpty);
        final second = applied(first, const Draw());
        expect(second.waste, cards('6H 5H 4H 3H 2H'));
        expect(second.lastDrawCount, 2);
        expect(second.stock, isEmpty);
        expect(refused(second, const Draw()), RefusalReason.stockEmpty);
        final recycled = applied(second, const Recycle());
        expect(recycled.stock, cards('2H* 3H* 4H* 5H* 6H*'));
        expect(recycled.waste, isEmpty);
        expect(recycled.lastDrawCount, 0);
      },
    );
  });

  group('auto-flip', () {
    test('on: the uncovered card turns up by itself', () {
      final game = klondike(
        tableau: [cards('KH* QS'), cards('KD'), [], [], [], [], []],
      );
      final next = applied(game, const MoveRun(0, 1, 1));
      expect(next.tableau[0], cards('KH'));
      expect(refused(next, const Flip(0)), RefusalReason.flipNotAllowed);
    });

    test('off: the card stays down until Flip, and nothing lands on it', () {
      final game = klondike(
        tableau: [cards('KH* QS'), cards('KD'), cards('QC'), [], [], [], []],
        options: const KlondikeOptions(autoFlip: false),
      );
      final next = applied(game, const MoveRun(0, 1, 1));
      expect(next.tableau[0], cards('KH*'));
      expect(refused(next, const MoveRun(2, 0, 0)), RefusalReason.notFaceUp);
      expect(next.legalMoves(), contains(const Flip(0)));
      final flipped = applied(next, const Flip(0));
      expect(flipped.tableau[0], cards('KH'));
      expect(flipped.moves, 2);
      expect(refused(flipped, const Flip(0)), RefusalReason.flipNotAllowed);
      expect(refused(flipped, const Flip(3)), RefusalReason.flipNotAllowed);
      expect(refused(flipped, const Flip(9)), RefusalReason.invalidMove);
    });
  });

  group('winning', () {
    test('a position one card short wins on the last foundation move', () {
      final game = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 12),
        ],
      );
      expect(game.isWon, isFalse);
      // The kings on the finished foundations may also come back onto the
      // empty columns, so the list is longer than the one winning move.
      expect(game.legalMoves().first, const TableauToFoundation(0));
      expect(
        game.legalMoves().skip(1),
        everyElement(anyOf(isA<MoveRun>(), isA<FoundationToTableau>())),
      );
      final won = applied(game, const TableauToFoundation(0));
      expect(won.isWon, isTrue);
      expect(won.legalMoves(), isEmpty);
      expect(refused(won, const Draw()), RefusalReason.gameOver);
      expect(won.tick(const Duration(seconds: 5)).elapsed, Duration.zero);
    });

    test(
      'a scripted game from a constructed near-end position reaches isWon',
      () {
        final game = klondike(
          tableau: [cards('2C AC'), cards('3C'), [], [], [], [], []],
          waste: cards('4C'),
          foundations: [
            suitRun(Suit.spades, 13),
            suitRun(Suit.hearts, 13),
            suitRun(Suit.diamonds, 13),
            [],
          ],
          stock: cards('KC* QC* JC* 10C* 9C* 8C* 7C* 6C* 5C*'),
        );
        var g = applied(game, const TableauToFoundation(0));
        g = applied(g, const TableauToFoundation(0));
        g = applied(g, const TableauToFoundation(1));
        g = applied(g, const WasteToFoundation());
        while (!g.isWon) {
          g = applied(g, const Draw());
          g = applied(g, const WasteToFoundation());
        }
        expect(g.isWon, isTrue);
        expect(g.foundations.every((f) => f.length == 13), isTrue);
      },
    );
  });

  group('legalMoves', () {
    test('lists every legal move in the fixed order', () {
      final game = klondike(
        tableau: [
          cards('8H* 7S 6D'),
          cards('8C'),
          cards('7D'),
          [],
          cards('KS'),
          cards('AC'),
          cards('2C'),
        ],
        waste: cards('AH 5S'),
        stock: cards('3H*'),
      );
      expect(game.legalMoves(), [
        const WasteToTableau(0),
        const MoveRun(2, 0, 1),
        const MoveRun(4, 0, 3),
        const TableauToFoundation(5),
        const Draw(),
      ]);
    });

    test('every legal move applies, over seeded random walks', () {
      for (var seed = 1; seed <= 10; seed++) {
        for (final draw in DrawMode.values) {
          var game = KlondikeGame.deal(
            DealNumber(seed),
            KlondikeOptions(draw: draw),
          );
          for (var step = 0; step < 60; step++) {
            final moves = game.legalMoves();
            if (moves.isEmpty) break;
            for (final move in moves) {
              expect(
                game.apply(move),
                isA<Applied<KlondikeGame>>(),
                reason: '$move on\n$game',
              );
            }
            game = applied(game, moves[(seed * 7 + step) % moves.length]);
          }
        }
      }
    });
  });

  group('fromPiles', () {
    test('refuses a duplicate, a missing card and a bad foundation', () {
      expect(
        () => KlondikeGame.fromPiles(
          tableau: [cards('AS AS'), [], [], [], [], [], []],
          stock: standardDeck().skip(1).toList(),
        ),
        throwsArgumentError,
      );
      expect(
        () => KlondikeGame.fromPiles(
          tableau: [cards('AS'), [], [], [], [], [], []],
          stock: standardDeck().skip(2).toList(),
        ),
        throwsArgumentError,
      );
      expect(
        () => KlondikeGame.fromPiles(
          tableau: [[], [], [], [], [], [], []],
          foundations: [cards('AH'), [], [], []],
          stock: standardDeck()
              .where((c) => c != const Card(1, Suit.hearts))
              .toList(),
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'options round-trip and default to draw 1, standard, timed, auto-flip',
    () {
      const options = KlondikeOptions();
      expect(options.draw, DrawMode.one);
      expect(options.scoring, ScoringMode.standard);
      expect(options.autoFlip, isTrue);
      expect(options.timed, isTrue);
      expect(options.toJson(), {
        'draw': 1,
        'scoring': 'standard',
        'autoFlip': true,
        'timed': true,
      });
    },
  );
}
