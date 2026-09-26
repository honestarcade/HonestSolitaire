import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/rng.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import 'positions.dart';

/// Applies up to [count] seeded random legal moves, stopping early if the
/// game runs out of moves or is won.
G walk<G extends Game>(G game, int seed, int count) {
  final rng = Rng(seed);
  var current = game;
  for (var i = 0; i < count; i++) {
    final moves = current.legalMoves();
    if (moves.isEmpty || current.isWon) break;
    current = applied(current, moves[rng.nextInt(moves.length)]);
  }
  return current;
}

G undoAll<G extends Game>(G game) {
  var current = game;
  while (current.canUndo(unlimited: true)) {
    current = (current.undo(unlimited: true) as Applied<G>).game;
  }
  return current;
}

void main() {
  group('unlimited undo walks back to the deal', () {
    for (final draw in DrawMode.values) {
      test('Klondike draw ${draw.count}, seeds 1–10, 200 moves', () {
        for (var seed = 1; seed <= 10; seed++) {
          final deal = KlondikeGame.deal(
            DealNumber(seed),
            KlondikeOptions(draw: draw),
          );
          final end = walk(deal, seed, 200);
          expect(end.historyLength, end.moves);
          final back = undoAll(end);
          expect(back, deal, reason: 'seed $seed');
          expect(back.historyLength, 0);
          expect(back.canUndo(unlimited: true), isFalse);
        }
      });
    }
    for (final suits in SpiderSuits.values) {
      test('Spider ${suits.count} suit(s), seeds 1–10, 200 moves', () {
        for (var seed = 1; seed <= 10; seed++) {
          final deal = SpiderGame.deal(
            DealNumber(seed),
            SpiderOptions(suits: suits),
          );
          final end = walk(deal, seed, 200);
          expect(end.historyLength, end.moves);
          expect(undoAll(end), deal, reason: 'seed $seed');
        }
      });
    }
  });

  test('undo restores cards, score and moves exactly, but not the clock', () {
    var g = klondike(
      tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
      waste: cards('AH'),
      moveScore: 20,
    );
    g = g.tick(const Duration(seconds: 4));
    final before = g;
    g = applied(g, const MoveRun(0, 1, 1));
    g = g.tick(const Duration(seconds: 6));
    expect(g.moveScore, 25);
    final result = g.undo(unlimited: true) as Applied<KlondikeGame>;
    expect(result.game, before);
    expect(
      result.game.tableau[0],
      cards('9H* 8S'),
      reason: 'the flipped card is face down again',
    );
    expect(result.game.moveScore, 20);
    expect(result.game.moves, 0);
    expect(
      result.game.elapsed,
      const Duration(seconds: 10),
      reason: 'time is never rewound',
    );
    expect(result.game.lastDelta, 0);
    expect(result.effects.steps.single.cardsFlipped, 1);
  });

  group('limited undo', () {
    test('undoes the latest move once, then refuses until a new move', () {
      var g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), cards('7H'), [], [], [], []],
      );
      g = applied(g, const MoveRun(0, 1, 1));
      g = applied(g, const MoveRun(2, 0, 1));
      expect(g.canUndo(unlimited: false), isTrue);
      g = (g.undo(unlimited: false) as Applied<KlondikeGame>).game;
      expect(g.tableau[2], cards('7H'));
      expect(g.canUndo(unlimited: false), isFalse);
      expect(g.undo(unlimited: false), isA<Refused>());
      expect(
        (g.undo(unlimited: false) as Refused).reason,
        RefusalReason.cannotUndo,
      );
      expect(
        g.canUndo(unlimited: true),
        isTrue,
        reason: 'the full history is still there',
      );
      g = applied(g, const MoveRun(2, 0, 1));
      expect(
        g.canUndo(unlimited: false),
        isTrue,
        reason: 'one undo per move, not per game',
      );
    });

    test('never undoes a draw, a recycle or a Spider row deal', () {
      var k = KlondikeGame.deal(DealNumber(1));
      k = applied(k, const Draw());
      expect(k.canUndo(unlimited: false), isFalse);
      expect(
        (k.undo(unlimited: false) as Refused).reason,
        RefusalReason.cannotUndo,
      );
      expect(k.canUndo(unlimited: true), isTrue);
      var empty = klondike(
        tableau: [cards('AS'), [], [], [], [], [], []],
        waste: cards('2H'),
      );
      empty = applied(empty, const Recycle());
      expect(empty.canUndo(unlimited: false), isFalse);
      var s = SpiderGame.deal(DealNumber(1));
      s = applied(s, const DealRow());
      expect(s.canUndo(unlimited: false), isFalse);
      expect(s.canUndo(unlimited: true), isTrue);
    });

    test('a manual flip can be undone in limited mode', () {
      var g = klondike(
        tableau: [cards('9H* 8S'), cards('9D'), [], [], [], [], []],
        options: const KlondikeOptions(autoFlip: false),
      );
      g = applied(g, const MoveRun(0, 1, 1));
      g = applied(g, const Flip(0));
      expect(g.canUndo(unlimited: false), isTrue);
      expect(
        (g.undo(unlimited: false) as Applied<KlondikeGame>).game.tableau[0],
        cards('9H*'),
      );
    });

    test(
      'turning the setting back on after limited undos reaches the deal',
      () {
        final deal = KlondikeGame.deal(DealNumber(5));
        var g = walk(deal, 5, 30);
        g = (g.undo(unlimited: false) is Applied<KlondikeGame>)
            ? (g.undo(unlimited: false) as Applied<KlondikeGame>).game
            : g;
        expect(g.canUndo(unlimited: false), isFalse);
        expect(undoAll(g), deal);
      },
    );
  });

  test('a won game cannot be undone', () {
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
    expect(won.isWon, isTrue);
    expect(won.canUndo(unlimited: true), isFalse);
    expect(won.canUndo(unlimited: false), isFalse);
    expect(
      (won.undo(unlimited: true) as Refused).reason,
      RefusalReason.cannotUndo,
    );
  });

  test(
    'undo of a Spider run completion restores the run, the flip and the score',
    () {
      final g = spider(
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
        options: const SpiderOptions(suits: SpiderSuits.two),
      );
      final done = applied(g, const MoveCards(1, 0, 0));
      expect(done.completed, [Suit.spades]);
      expect(done.score, 599);
      final back = (done.undo(unlimited: true) as Applied<SpiderGame>).game;
      expect(back, g);
      expect(back.tableau[0], hasLength(13));
      expect(back.tableau[0].first, c('5H*'));
      expect(back.tableau[1], cards('AS'));
      expect(back.completed, isEmpty);
      expect(back.score, 500);
    },
  );

  group('restart', () {
    test(
      'equals a fresh deal of the same number and options, Vegas at −52',
      () {
        const options = KlondikeOptions(
          draw: DrawMode.three,
          scoring: ScoringMode.vegas,
        );
        var g = KlondikeGame.deal(DealNumber(42), options);
        g = walk(g, 42, 40).tick(const Duration(minutes: 3));
        final again = g.restart();
        expect(again, KlondikeGame.deal(DealNumber(42), options));
        expect(again.score, -52);
        expect(again.elapsed, Duration.zero);
        expect(again.moves, 0);
        expect(again.historyLength, 0);
        expect(again.lastDrawCount, 0);
        expect(
          again.canUndo(unlimited: true),
          isFalse,
          reason: 'a restart cannot be undone',
        );
        expect(
          (again.undo(unlimited: true) as Refused).reason,
          RefusalReason.cannotUndo,
        );
        var s = walk(
          SpiderGame.deal(
            DealNumber(7),
            const SpiderOptions(suits: SpiderSuits.four),
          ),
          7,
          40,
        );
        s = s.tick(const Duration(seconds: 90));
        expect(
          s.restart(),
          SpiderGame.deal(
            DealNumber(7),
            const SpiderOptions(suits: SpiderSuits.four),
          ),
        );
        expect(s.restart().elapsed, Duration.zero);
      },
    );

    test('is allowed on a won game', () {
      final g = klondike(
        tableau: [cards('KC'), [], [], [], [], [], []],
        foundations: [
          suitRun(Suit.spades, 13),
          suitRun(Suit.hearts, 13),
          suitRun(Suit.diamonds, 13),
          suitRun(Suit.clubs, 12),
        ],
        dealNumber: 9,
      );
      final won = applied(g, const TableauToFoundation(0));
      expect(won.timeBonus, greaterThan(0));
      final again = won.restart();
      expect(again, KlondikeGame.deal(DealNumber(9)));
      expect(again.timeBonus, 0);
      expect(again.isWon, isFalse);
    });
  });

  test('a grouped apply is one history entry and one undo step', () {
    final g = klondike(
      tableau: [cards('2C AC'), cards('3C'), [], [], [], [], []],
      foundations: [
        suitRun(Suit.spades, 13),
        suitRun(Suit.hearts, 13),
        suitRun(Suit.diamonds, 13),
        [],
      ],
      stock: cards('KC* QC* JC* 10C* 9C* 8C* 7C* 6C* 5C* 4C*'),
    );
    final result = g.applyAll(const [
      TableauToFoundation(0),
      TableauToFoundation(0),
      TableauToFoundation(1),
    ]);
    final grouped = (result as Applied<Game>).game as KlondikeGame;
    expect(grouped.moves, 3);
    expect(grouped.moveScore, 30);
    expect(grouped.historyLength, 1);
    expect(result.effects.steps, hasLength(3));
    expect(result.effects.cardsMoved, 3);
    expect((grouped.undo(unlimited: false) as Applied<KlondikeGame>).game, g);
    final refused = g.applyAll(const [
      TableauToFoundation(0),
      Draw(),
      Recycle(),
    ]);
    expect((refused as Refused).reason, RefusalReason.stockNotEmpty);
    expect((g.applyAll(const []) as Applied).game, g);
  });

  test('a 1,000-move Klondike walk keeps a 1,000-long history and undoes to the deal', () {
    final deal = KlondikeGame.deal(DealNumber(1));
    final rng = Rng(1);
    var g = deal;
    for (var i = 0; i < 1000; i++) {
      final moves = g.legalMoves();
      // Alternate a random legal move with a draw (or recycle) so the walk
      // never runs dry: with draw 1 the stock and waste always hold 24.
      final move = i.isEven
          ? moves[rng.nextInt(moves.length)]
          : moves.firstWhere((m) => m is Draw || m is Recycle);
      g = applied(g, move);
    }
    expect(g.moves, 1000);
    expect(g.historyLength, 1000);
    expect(g.historyMoves, hasLength(1000));
    expect(undoAll(g), deal);
  });
}
