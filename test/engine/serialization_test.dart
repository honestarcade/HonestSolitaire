import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/rng.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import 'positions.dart';

G walk<G extends Game>(G game, int seed, int count) {
  final rng = Rng(seed);
  var g = game;
  for (var i = 0; i < count; i++) {
    final moves = g.legalMoves();
    if (moves.isEmpty || g.isWon) break;
    g = applied(g, moves[rng.nextInt(moves.length)]);
  }
  return g.tick(Duration(milliseconds: 1234 * (count + 1))) as G;
}

/// Through real JSON text, so nothing non-JSON can hide in the map.
Map<String, Object?> viaText(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

G undoAll<G extends Game>(G game) {
  var g = game;
  while (g.canUndo(unlimited: true)) {
    g = (g.undo(unlimited: true) as Applied<G>).game;
  }
  return g;
}

void main() {
  final klondikeVariants = <KlondikeOptions>[
    for (final draw in DrawMode.values)
      for (final scoring in ScoringMode.values)
        KlondikeOptions(draw: draw, scoring: scoring),
    const KlondikeOptions(autoFlip: false, timed: false),
  ];
  final spiderVariants = <SpiderOptions>[
    for (final suits in SpiderSuits.values) SpiderOptions(suits: suits),
    const SpiderOptions(relaxed: true, autoFlip: false, timed: false),
  ];

  group('round trips are exact', () {
    for (final count in [0, 1, 200]) {
      test('Klondike after $count moves, every draw and scoring mode', () {
        for (final options in klondikeVariants) {
          final g = walk(KlondikeGame.deal(DealNumber(3), options), 3, count);
          final back = KlondikeGame.fromJson(viaText(g.toJson()));
          expect(back, g, reason: '$options');
          expect(back.elapsed, g.elapsed);
          expect(back.lastDrawCount, g.lastDrawCount);
          expect(back.historyLength, g.historyLength);
          expect(back.historyMoves, g.historyMoves);
          expect(back.score, g.score);
          expect(back.toJson(), g.toJson(), reason: 'stable output');
          expect(Game.fromJson(viaText(g.toJson())), g);
        }
      });

      test('Spider after $count moves, every suit count', () {
        for (final options in spiderVariants) {
          final g = walk(SpiderGame.deal(DealNumber(3), options), 3, count);
          final back = SpiderGame.fromJson(viaText(g.toJson()));
          expect(back, g, reason: '$options');
          expect(back.elapsed, g.elapsed);
          expect(back.historyLength, g.historyLength);
          expect(back.toJson(), g.toJson());
          expect(Game.fromJson(viaText(g.toJson())), g);
        }
      });
    }

    test('undo after a round trip equals undo without', () {
      final k = walk(KlondikeGame.deal(DealNumber(5)), 5, 60);
      final kBack = KlondikeGame.fromJson(viaText(k.toJson()));
      var a = k;
      var b = kBack;
      for (var i = 0; i < 10; i++) {
        a = (a.undo(unlimited: true) as Applied<KlondikeGame>).game;
        b = (b.undo(unlimited: true) as Applied<KlondikeGame>).game;
        expect(b, a);
      }
      expect(undoAll(kBack), KlondikeGame.deal(DealNumber(5)));
      final s = walk(SpiderGame.deal(DealNumber(5)), 5, 60);
      expect(
        undoAll(SpiderGame.fromJson(viaText(s.toJson()))),
        SpiderGame.deal(DealNumber(5)),
      );
      // Limited mode still refuses a second undo after a round trip.
      expect(kBack.canUndo(unlimited: false), k.canUndo(unlimited: false));
    });

    test('lastUndone survives the trip: limited mode still refuses right after reload (#135)', () {
      final k = walk(KlondikeGame.deal(DealNumber(7)), 7, 40);
      final undone = (k.undo(unlimited: true) as Applied<KlondikeGame>).game;
      expect(undone.lastUndone, isTrue);
      expect(undone.canUndo(unlimited: false), isFalse);
      final reloaded = KlondikeGame.fromJson(viaText(undone.toJson()));
      expect(reloaded.lastUndone, isTrue);
      expect(
        reloaded.canUndo(unlimited: false),
        isFalse,
        reason: 'a reload must not let the same move be undone twice',
      );

      final s = walk(SpiderGame.deal(DealNumber(7)), 7, 40);
      final sUndone = (s.undo(unlimited: true) as Applied<SpiderGame>).game;
      expect(sUndone.lastUndone, isTrue);
      final sReloaded = SpiderGame.fromJson(viaText(sUndone.toJson()));
      expect(sReloaded.lastUndone, isTrue);
      expect(sReloaded.canUndo(unlimited: false), isFalse);

      // A save with no lastUndone field (an older save) loads as false.
      final noField = viaText(k.toJson())..remove('lastUndone');
      expect(KlondikeGame.fromJson(noField).lastUndone, isFalse);
    });

    test('a grouped finish and a won game survive the trip', () {
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
        dealNumber: 77,
      ).tick(const Duration(seconds: 120));
      // A position built with fromPiles does not follow from a deal, so it
      // cannot round-trip; this covers the grouped move's encoding alone.
      final grouped = (g.applyAll(const [
        TableauToFoundation(0),
        TableauToFoundation(1),
      ]) as Applied).game;
      final json = viaText(grouped.toJson());
      expect((json['history'] as List).single, containsPair('kind', 'group'));
      final moves = Move.fromJson(
        (json['history'] as List).single as Map<String, Object?>,
      );
      expect(
        moves,
        const MoveGroup([TableauToFoundation(0), TableauToFoundation(1)]),
      );
    });

    test(
      'a winnable game keeps winnable only when its solution replays',
      () async {
        final events = await WinnableDealer.search(
          DealNumber(1),
          const KlondikeOptions(),
          softLimit: null,
        ).events.toList();
        final found = (events.last as Found).game;
        final played = applied(
          found,
          found.solution!.first,
        ).tick(const Duration(seconds: 9));
        final back = KlondikeGame.fromJson(viaText(played.toJson()));
        expect(back, played);
        expect(back.winnable, isTrue);
        expect(back.solution, found.solution);
        // A tampered solution loses the flag.
        final tampered = viaText(played.toJson());
        (tampered['solution'] as List).removeLast();
        final honest = KlondikeGame.fromJson(tampered);
        expect(honest.winnable, isFalse);
        expect(honest.solution, isNull);
        // A flag without a solution is not believed either.
        final bare = viaText(played.toJson())..remove('solution');
        expect(KlondikeGame.fromJson(bare).winnable, isFalse);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('the committed fixture keeps loading', () {
    final fixture = jsonDecode(
      File('test/fixtures/save_v1.json').readAsStringSync(),
    ) as Map<String, Object?>;

    test('Klondike', () {
      final g = Game.fromJson(
        fixture['klondike'] as Map<String, Object?>,
      ) as KlondikeGame;
      expect(g.dealNumber.value, 1);
      expect(g.options.draw, DrawMode.three);
      expect(g.moves, 12);
      expect(g.historyLength, 12);
      expect(g.elapsed, const Duration(seconds: 61));
      expect(
        g.toJson(),
        fixture['klondike'],
        reason: 'the format did not drift',
      );
    });

    test('Spider', () {
      final g = Game.fromJson(
        fixture['spider'] as Map<String, Object?>,
      ) as SpiderGame;
      expect(g.dealNumber.value, 1);
      expect(g.options.suits, SpiderSuits.two);
      expect(g.moves, 8);
      expect(g.score, 492);
      expect(g.toJson(), fixture['spider']);
    });
  });

  group('malformed input gives its typed error', () {
    Map<String, Object?> k() =>
        viaText(walk(KlondikeGame.deal(DealNumber(2)), 2, 20).toJson());
    Map<String, Object?> s() =>
        viaText(walk(SpiderGame.deal(DealNumber(2)), 2, 20).toJson());

    test('format 2 is unsupported', () {
      expect(
        () => Game.fromJson(k()..['format'] = 2),
        throwsA(isA<UnsupportedFormatError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..remove('format')),
        throwsA(isA<MissingFieldError>()),
      );
    });

    test('a missing pile or field', () {
      expect(
        () => KlondikeGame.fromJson(k()..remove('waste')),
        throwsA(isA<MissingFieldError>()),
      );
      expect(
        () => SpiderGame.fromJson(s()..remove('stock')),
        throwsA(isA<MissingFieldError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..remove('history')),
        throwsA(isA<MissingFieldError>()),
      );
      expect(
        () => Game.fromJson(k()..remove('game')),
        throwsA(isA<MissingFieldError>()),
      );
    });

    test('a wrong-shaped value', () {
      expect(
        () => KlondikeGame.fromJson(k()..['deal'] = 0),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..['deal'] = 'one'),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..['moves'] = -1),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..['tableau'] = [[]]),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..['options'] = {'draw': 2}),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => Game.fromJson(k()..['game'] = 'pyramid'),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => SpiderGame.fromJson(s()..['completed'] = ['X']),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => KlondikeGame.fromJson(
          k()
            ..['history'] = [
              {'kind': 'teleport'},
            ],
        ),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => KlondikeGame.fromJson(k()..['stock'] = ['1S']),
        throwsA(isA<InvalidValueError>()),
      );
      expect(
        () => SpiderGame.fromJson(k()),
        throwsA(isA<InvalidValueError>()),
        reason: 'a Klondike save is not a Spider game',
      );
    });

    test(
      'an out-of-range elapsedMs is refused, not a Duration overflow (#135)',
      () {
        // Comfortably past int64 microseconds ÷ 1000 — the value the repro
        // in #135 used, which overflows Duration's internal microseconds
        // before this bound existed.
        const huge = 9223372036854775807;
        expect(
          () => KlondikeGame.fromJson(k()..['elapsedMs'] = huge),
          throwsA(isA<InvalidValueError>()),
        );
        expect(
          () => SpiderGame.fromJson(s()..['elapsedMs'] = huge),
          throwsA(isA<InvalidValueError>()),
        );
        // Just over the documented ceiling, not just an absurd one.
        expect(
          () => KlondikeGame.fromJson(
            k()..['elapsedMs'] = 365 * 24 * 3600 * 1000 + 1,
          ),
          throwsA(isA<InvalidValueError>()),
        );
      },
    );

    test('a present but non-bool lastUndone is refused (#135)', () {
      expect(
        () => KlondikeGame.fromJson(k()..['lastUndone'] = 'yes'),
        throwsA(isA<InvalidValueError>()),
      );
    });

    test('a duplicated card, a 51-card deck, a wrong Spider deck', () {
      final dup = k();
      (dup['stock'] as List)[0] = (dup['stock'] as List)[1];
      expect(
        () => KlondikeGame.fromJson(dup),
        throwsA(isA<InvalidDeckError>()),
      );
      final short = k();
      (short['stock'] as List).removeLast();
      expect(
        () => KlondikeGame.fromJson(short),
        throwsA(isA<InvalidDeckError>()),
      );
      final wrongSuit = s();
      wrongSuit['options'] = const SpiderOptions(suits: SpiderSuits.four)
          .toJson();
      expect(
        () => SpiderGame.fromJson(wrongSuit),
        throwsA(isA<InvalidDeckError>()),
      );
    });

    test('piles that do not follow from the history', () {
      final moved = k();
      final tableau = (moved['tableau'] as List).cast<List>();
      // Swap two columns: still a valid deck, but not the replayed position.
      final t = tableau[0];
      tableau[0] = tableau[1];
      tableau[1] = t;
      expect(
        () => KlondikeGame.fromJson(moved),
        throwsA(isA<InvalidDeckError>()),
      );
      final score = k()..['moveScore'] = 999;
      expect(
        () => KlondikeGame.fromJson(score),
        throwsA(isA<InvalidDeckError>()),
      );
      final history = k();
      (history['history'] as List).removeLast();
      expect(
        () => KlondikeGame.fromJson(history),
        throwsA(isA<InvalidDeckError>()),
      );
      final faceDown = k();
      (faceDown['waste'] as List).add('9Z');
      expect(
        () => KlondikeGame.fromJson(faceDown),
        throwsA(isA<InvalidValueError>()),
      );
    });

    test('an illegal history move is refused, not applied', () {
      final bad = k();
      (bad['history'] as List).insert(0, const MoveRun(0, 0, 0).toJson());
      expect(
        () => KlondikeGame.fromJson(bad),
        throwsA(isA<InvalidDeckError>()),
      );
    });
  });
}
