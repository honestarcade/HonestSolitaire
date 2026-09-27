import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/board_layout.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';

import '../engine/positions.dart';

const phone = Size(390, 844);
const options = DisplayOptions();

Matcher near(double v) => closeTo(v, 0.01);

void expectRect(Rect r, double l, double t, double w, double h) {
  expect(r.left, near(l), reason: 'left');
  expect(r.top, near(t), reason: 'top');
  expect(r.width, near(w), reason: 'width');
  expect(r.height, near(h), reason: 'height');
}

void main() {
  group('Klondike at the design frame', () {
    final game = KlondikeGame.deal(
      DealNumber(7),
      const KlondikeOptions(draw: DrawMode.three),
    );
    final layout = layoutBoard(game, phone, options);

    test('columns sit at the design x positions with 48×72 cards', () {
      expect(layout.scale, 1);
      expect(layout.cardSize, const Size(48, 72));
      expect(layout.radius, 6);
      expect(layout.narrow, isFalse);
      for (var c = 0; c < 7; c++) {
        expectRect(
          layout.slots[TableauPile(c)]!,
          12 + c * 53,
          48 + 72 + 14,
          48,
          72,
        );
      }
      expectRect(layout.topBar, 0, 0, 390, 44);
      expectRect(layout.topRow, 0, 48, 390, 72);
      expectRect(layout.toolRow, 0, 844 - 84, 390, 84);
      expect(layout.tableau.bottom, near(844 - 84 - 8));
    });

    test('the top row: stock, fanned waste, foundations in suit order', () {
      expectRect(layout.slots[const StockPile()]!, 12, 48, 48, 72);
      expectRect(layout.slots[const WastePile()]!, 65, 48, 66, 72);
      for (final suit in Suit.values) {
        expectRect(
          layout.slots[FoundationPile(suit)]!,
          12 + (3 + suit.index) * 53,
          48,
          48,
          72,
        );
      }
      expect(layout.cards[const StockPile()], hasLength(24));
      expect(layout.cards[const WastePile()], isEmpty);
      final drawn = applied(game, const Draw());
      final fan = layoutBoard(drawn, phone, options).cards[const WastePile()]!;
      expect(fan, hasLength(3));
      expect(fan.map((r) => r.left), [65, 74, 83]);
      final twice = applied(drawn, const Draw());
      final fan2 = layoutBoard(twice, phone, options).cards[const WastePile()]!;
      expect(fan2, hasLength(6));
      expect(fan2.take(3).map((r) => r.left), everyElement(65));
      expect(fan2.skip(3).map((r) => r.left), [65, 74, 83]);
    });

    test('face-down and face-up offsets are 6 and 17', () {
      final column = layout.cards[const TableauPile(6)]!;
      expect(column, hasLength(7));
      for (var i = 1; i < 6; i++) {
        expect(column[i].top - column[i - 1].top, near(6));
      }
      final withRun = klondike(
        tableau: [cards('KS* QD JC 10D 9C'), [], [], [], [], [], []],
      );
      final run = layoutBoard(
        withRun,
        phone,
        options,
      ).cards[const TableauPile(0)]!;
      expect(run[1].top - run[0].top, near(6));
      expect(run[2].top - run[1].top, near(17));
      expect(run[4].top - run[3].top, near(17));
      expect(layoutBoard(withRun, phone, options).columnStrips[0].left, 0);
      expect(
        layoutBoard(withRun, phone, options).columnStrips[1].left,
        near(12 + 53 - 2.5),
      );
    });
  });

  test('at 430×932 everything scales by 430/390', () {
    final game = KlondikeGame.deal(DealNumber(7));
    final s = 430 / 390;
    final layout = layoutBoard(game, const Size(430, 932), options);
    expect(layout.scale, near(s));
    expect(layout.cardSize.width, near(48 * s));
    expect(layout.cardSize.height, near(72 * s));
    expect(layout.slots[const TableauPile(2)]!.left, near((12 + 2 * 53) * s));
    expect(layout.slots[const TableauPile(2)]!.top, near((48 + 72 + 14) * s));
    expect(layout.toolRow.height, near(84 * s));
    expect(layout.faceUpOffset, near(17 * s));
  });

  test('a board wider than 480 is capped and centred', () {
    final layout = layoutBoard(
      KlondikeGame.deal(DealNumber(7)),
      const Size(600, 1000),
      options,
    );
    expect(layout.scale, near(480 / 390));
    expect(layout.boardRect.left, 60);
    expect(layout.boardRect.width, 480);
    expect(layout.slots[const TableauPile(0)]!.left, near(60 + 12 * 480 / 390));
  });

  group('large cards', () {
    test('Klondike: 52×78 with fractional gaps filling the frame exactly', () {
      final layout = layoutBoard(
        KlondikeGame.deal(DealNumber(7)),
        phone,
        const DisplayOptions(largeCards: true),
      );
      expect(layout.cardSize, const Size(52, 78));
      final gap = (390 - 7 * 52) / 6;
      expect(layout.slots[const TableauPile(0)]!.left, near(0));
      expect(layout.slots[const TableauPile(1)]!.left, near(52 + gap));
      expect(layout.slots[const TableauPile(6)]!.right, near(390));
      expect(layout.faceUpOffset, near(19));
      expect(layout.slots[const TableauPile(0)]!.top, near(48 + 78 + 14));
    });

    test('Spider: 36×54, offsets 15, top row unchanged', () {
      final small = layoutBoard(SpiderGame.deal(DealNumber(1)), phone, options);
      final large = layoutBoard(
        SpiderGame.deal(DealNumber(1)),
        phone,
        const DisplayOptions(largeCards: true),
      );
      expect(small.cardSize, const Size(34, 52));
      expect(large.cardSize, const Size(36, 54));
      expect(small.faceUpOffset, near(14));
      expect(large.faceUpOffset, near(15));
      expect(large.slots[const StockPile()], small.slots[const StockPile()]);
      expect(
        large.slots[const CompletedPile(3)],
        small.slots[const CompletedPile(3)],
      );
    });
  });

  group('Spider at the design frame', () {
    final game = SpiderGame.deal(DealNumber(11));
    final layout = layoutBoard(game, phone, options);

    test(
      'ten columns of 34×52 with 3-point gaps, tableau 58 below the top row',
      () {
        expect(layout.narrow, isTrue);
        expect(layout.radius, 5);
        expect(layout.topRowRadius, 4);
        final x0 = (390 - (10 * 34 + 9 * 3)) / 2;
        for (var c = 0; c < 10; c++) {
          expectRect(
            layout.slots[TableauPile(c)]!,
            x0 + c * 37,
            48 + 58,
            34,
            52,
          );
        }
        expect(layout.cards[const TableauPile(0)], hasLength(6));
        expect(layout.cards[const TableauPile(9)], hasLength(5));
        expect(
          layout.cards[const TableauPile(0)]![1].top -
              layout.cards[const TableauPile(0)]![0].top,
          near(5),
        );
      },
    );

    test('completed slots at the left 20 apart, stock slivers at the right 7 apart', () {
      for (var i = 0; i < 8; i++) {
        expectRect(layout.slots[CompletedPile(i)]!, 14 + i * 20, 50, 20, 36);
        expect(layout.cards[CompletedPile(i)], isEmpty);
      }
      final stock = layout.slots[const StockPile()]!;
      expectRect(stock, 390 - 14 - 26 - 4 * 7, 50, 26 + 4 * 7, 36);
      final slivers = layout.cards[const StockPile()]!;
      expect(slivers, hasLength(5));
      expect(
        slivers[0].left,
        near(stock.right - 26),
        reason: 'index 0 is the next row, rightmost',
      );
      expect(slivers[4].left, near(stock.left));
      final dealt = layoutBoard(applied(game, const DealRow()), phone, options);
      expect(dealt.cards[const StockPile()], hasLength(4));
      expect(
        dealt.slots[const StockPile()]!.left,
        near(stock.left + 7),
        reason: 'the left edge moves in',
      );
      expect(dealt.slots[const StockPile()]!.right, near(stock.right));
    });

    test('a completed run fills its slot', () {
      final near = spider(
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
      final done = applied(near, const MoveCards(1, 0, 0));
      final l = layoutBoard(done, phone, options);
      expect(l.cards[const CompletedPile(0)], hasLength(1));
      expect(l.cards[const CompletedPile(1)], isEmpty);
    });
  });

  group('compression', () {
    test('a tall face-up Spider column compresses evenly to end above the tool row, never under 7', () {
      final tall = spider(
        tableau: [
          [
            for (var i = 0; i < 40; i++)
              Card(13 - i % 13, Suit.spades, faceUp: true),
          ],
          [],
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
      const small = Size(320, 568);
      final layout = layoutBoard(tall, small, options);
      final s = 320 / 390;
      final column = layout.cards[const TableauPile(0)]!;
      expect(column, hasLength(40));
      final step = column[1].top - column[0].top;
      expect(step, lessThan(14 * s), reason: 'compressed');
      expect(step, greaterThanOrEqualTo(7 * s - 0.01));
      for (var i = 2; i < 40; i++) {
        expect(column[i].top - column[i - 1].top, near(step), reason: 'even');
      }
      expect(
        column.last.bottom,
        lessThanOrEqualTo(layout.tableau.bottom + 0.01),
      );
      expect(column.last.bottom, lessThan(layout.toolRow.top));
    });

    test('a column that cannot fit floors at 7-point offsets', () {
      final huge = spider(
        tableau: [
          [
            for (var i = 0; i < 70; i++)
              Card(13 - i % 13, Suit.spades, faceUp: true),
          ],
          [],
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
      final layout = layoutBoard(huge, const Size(320, 568), options);
      final column = layout.cards[const TableauPile(0)]!;
      expect(column[1].top - column[0].top, near(7 * 320 / 390));
    });

    test('face-down offsets shrink towards 3 only after face-up ones hit the floor', () {
      final many = spider(
        tableau: [
          [
            for (var i = 0; i < 50; i++) Card(13 - i % 13, Suit.spades),
            for (var i = 0; i < 30; i++)
              Card(13 - i % 13, Suit.spades, faceUp: true),
          ],
          [],
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
      final layout = layoutBoard(many, const Size(320, 568), options);
      final column = layout.cards[const TableauPile(0)]!;
      final s = 320 / 390;
      expect(
        column[51].top - column[50].top,
        near(7 * s),
        reason: 'face-up at the floor',
      );
      final down = column[1].top - column[0].top;
      expect(down, lessThan(5 * s));
      expect(down, greaterThanOrEqualTo(3 * s - 0.01));
    });

    test(
      'an uncompressed column is untouched, and peek expands a compressed one',
      () {
        final game = SpiderGame.deal(DealNumber(11));
        final layout = layoutBoard(game, phone, options);
        expect(
          layoutColumn(game, 0, layout),
          layout.cards[const TableauPile(0)],
        );
        final tall = spider(
          tableau: [
            [
              for (var i = 0; i < 40; i++)
                Card(13 - i % 13, Suit.spades, faceUp: true),
            ],
            [],
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
        final l = layoutBoard(tall, const Size(320, 568), options);
        final compressed = l.cards[const TableauPile(0)]!;
        final peeked = layoutColumn(tall, 0, l, peek: true);
        expect(
          peeked[1].top - peeked[0].top,
          greaterThan(compressed[1].top - compressed[0].top),
        );
        expect(peeked.last.bottom, lessThanOrEqualTo(l.tableau.bottom + 0.01));
      },
    );
  });

  group('left-handed', () {
    test(
      'Klondike mirrors the top row exactly and leaves the tableau alone',
      () {
        final game = KlondikeGame.deal(
          DealNumber(7),
          const KlondikeOptions(draw: DrawMode.three),
        );
        final right = layoutBoard(game, phone, options);
        final left = layoutBoard(
          game,
          phone,
          const DisplayOptions(leftHanded: true),
        );
        Rect m(Rect r) =>
            Rect.fromLTWH(390 - r.right, r.top, r.width, r.height);
        expect(
          left.slots[const StockPile()],
          m(right.slots[const StockPile()]!),
        );
        expect(
          left.slots[const WastePile()],
          m(right.slots[const WastePile()]!),
        );
        for (final suit in Suit.values) {
          expect(
            left.slots[FoundationPile(suit)],
            m(right.slots[FoundationPile(suit)]!),
          );
        }
        expect(
          left.slots[const FoundationPile(Suit.clubs)]!.left,
          near(12),
          reason: 'clubs first at the left',
        );
        expect(
          left.slots[const FoundationPile(Suit.spades)]!.left,
          near(12 + 3 * 53),
        );
        expect(left.slots[const StockPile()]!.left, near(12 + 6 * 53));
        for (var c = 0; c < 7; c++) {
          expect(left.slots[TableauPile(c)], right.slots[TableauPile(c)]);
          expect(left.cards[TableauPile(c)], right.cards[TableauPile(c)]);
        }
        final drawn = applied(game, const Draw());
        final fan = layoutBoard(
          drawn,
          phone,
          const DisplayOptions(leftHanded: true),
        ).cards[const WastePile()]!;
        expect(fan.map((r) => r.left), [
          390 - 65 - 48,
          390 - 74 - 48,
          390 - 83 - 48,
        ], reason: 'fans leftward');
      },
    );

    test(
      'Spider puts the stock at the left and the completed slots at the right',
      () {
        final game = SpiderGame.deal(DealNumber(11));
        final left = layoutBoard(
          game,
          phone,
          const DisplayOptions(leftHanded: true),
        );
        expect(left.slots[const StockPile()]!.left, near(14));
        expect(left.slots[const CompletedPile(0)]!.right, near(390 - 14));
        expect(
          left.slots[const CompletedPile(7)]!.right,
          near(390 - 14 - 7 * 20),
        );
        final slivers = left.cards[const StockPile()]!;
        expect(
          slivers[0].left,
          near(14),
          reason: 'the next row is now leftmost',
        );
      },
    );
  });

  group('hitTest', () {
    final game = klondike(
      tableau: [cards('KS* QD JC 10D 9C'), cards('AS'), [], [], [], [], []],
      waste: cards('2H 3H 4H'),
      foundations: [[], cards('AH'), [], []],
    );
    final layout = layoutBoard(game, phone, options);

    test('overlapping cards return the topmost', () {
      final rects = layout.cards[const TableauPile(0)]!;
      // A point inside card 2 and card 3 (they overlap by 72 − 17).
      final point = Offset(rects[3].left + 10, rects[3].top + 5);
      expect(hitTest(layout, point), (const TableauPile(0), 3));
      expect(hitTest(layout, Offset(rects[0].left + 10, rects[0].top + 2)), (
        const TableauPile(0),
        0,
      ));
      expect(hitTest(layout, Offset(rects[4].left + 10, rects[4].bottom - 2)), (
        const TableauPile(0),
        4,
      ));
    });

    test('below a column\'s last card hits the column; the strip widens to the gap midpoints', () {
      final rects = layout.cards[const TableauPile(1)]!;
      expect(
        hitTest(layout, Offset(rects.last.left + 5, rects.last.bottom + 40)),
        (const TableauPile(1), null),
      );
      expect(
        hitTest(
          layout,
          Offset(
            layout.slots[const TableauPile(2)]!.left + 5,
            layout.tableau.top + 10,
          ),
        ),
        (const TableauPile(2), null),
      );
      // Just inside the gap left of column 1, still column 1.
      expect(
        hitTest(
          layout,
          Offset(
            layout.slots[const TableauPile(1)]!.left - 2,
            layout.tableau.top + 10,
          ),
        ),
        (const TableauPile(1), null),
      );
      expect(
        hitTest(
          layout,
          Offset(
            layout.slots[const TableauPile(1)]!.left - 3,
            layout.tableau.top + 10,
          ),
        ),
        (const TableauPile(0), null),
      );
    });

    test('top-row piles: stock null, waste top index, foundation top, empty foundation null', () {
      expect(hitTest(layout, layout.slots[const StockPile()]!.center), (
        const StockPile(),
        null,
      ));
      expect(hitTest(layout, layout.slots[const WastePile()]!.center), (
        const WastePile(),
        2,
      ));
      expect(
        hitTest(
          layout,
          layout.slots[const FoundationPile(Suit.hearts)]!.center,
        ),
        (const FoundationPile(Suit.hearts), 0),
      );
      expect(
        hitTest(
          layout,
          layout.slots[const FoundationPile(Suit.spades)]!.center,
        ),
        (const FoundationPile(Suit.spades), null),
      );
    });

    test('felt and the top bar return null', () {
      expect(hitTest(layout, const Offset(200, 20)), isNull);
      expect(
        hitTest(layout, Offset(5, layout.topRow.top + 200)),
        isNot(isNull),
        reason: 'the first strip reaches the edge',
      );
      expect(hitTest(layout, Offset(200, layout.toolRow.top + 10)), isNull);
    });

    test('Spider: slivers hit the stock, completed slots hit themselves', () {
      final s = SpiderGame.deal(DealNumber(11));
      final l = layoutBoard(s, phone, options);
      expect(hitTest(l, l.cards[const StockPile()]![2].center), (
        const StockPile(),
        null,
      ));
      expect(hitTest(l, l.slots[const CompletedPile(3)]!.center), (
        const CompletedPile(3),
        null,
      ));
    });
  });

  test('DisplayOptions is a value', () {
    const a = DisplayOptions();
    expect(a, const DisplayOptions());
    expect(a.copyWith(largeCards: true), isNot(a));
    expect(a.copyWith(cardBack: CardBack.teal).cardBack, CardBack.teal);
    expect(a.toString(), contains('navy'));
  });

  test('BoardLayout is a value', () {
    final g = KlondikeGame.deal(DealNumber(3));
    expect(layoutBoard(g, phone, options), layoutBoard(g, phone, options));
    expect(
      layoutBoard(g, phone, options),
      isNot(layoutBoard(g, phone, const DisplayOptions(leftHanded: true))),
    );
    expect(SpiderSuits.values, hasLength(3));
  });
}
