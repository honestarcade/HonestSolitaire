@Tags(['guard', 'slow'])
library;

// Invariant 4: "Winnable deals only" is honest (#70).
//
// A deal the app marks winnable must have been proven by the on-device
// solver: for fixed bases in both draw modes the dealer's `Found` game must
// carry a solution that replays through `apply` to `isWon`, and must equal a
// fresh deal of the found number; and no deal from `deal` or from
// `DealNumber.random()` is ever marked winnable on its own.
//
// What this does not cover: Spider winnability (the app does not offer it),
// deal numbers outside the sampled bases, and the uniformity of the random
// shuffle when the option is off (not measured — honor-system).

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

/// Bases 1–10 plus ten spread across the range, including the wrap.
const bases = [
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  50000,
  123456,
  250000,
  333333,
  500000,
  654321,
  777777,
  900000,
  999998,
  999999,
];

const perSearch = Duration(seconds: 60);

Future<Found> findFrom(int base, KlondikeOptions options) async {
  final events =
      await WinnableDealer.search(
        DealNumber(base),
        options,
        softLimit: null,
      ).events.toList().timeout(
        perSearch,
        onTimeout: () => fail(
          'engine-winnable: the search from base $base took more than $perSearch',
        ),
      );
  final last = events.last;
  if (last is! Found) {
    fail(
      'engine-winnable: the search from base $base ended in $last, not Found',
    );
  }
  return last;
}

void main() {
  for (final draw in DrawMode.values) {
    final options = KlondikeOptions(draw: draw);

    test('draw ${draw.count}: every found deal replays its solution to a win', () async {
      // All twenty searches at once: each runs in its own isolate.
      final results = await Future.wait([
        for (final base in bases)
          findFrom(base, options)
              .then((found) => (base, found))
              .catchError(
                (Object error) => fail(
                  'engine-winnable: a deal marked winnable did not win — search from base $base failed: $error',
                ),
              ),
      ]);
      for (final (base, found) in results) {
        final game = found.game;
        expect(
          game.winnable,
          isTrue,
          reason: 'engine-winnable: base $base: Found carried winnable false',
        );
        expect(
          game.options,
          options,
          reason: 'engine-winnable: base $base: wrong options',
        );
        final fresh = KlondikeGame.deal(game.dealNumber, options);
        expect(
          game,
          fresh,
          reason:
              'engine-winnable: base $base: the found game is not a fresh deal of #${game.dealNumber.value}',
        );
        var g = fresh;
        for (final move in found.solution) {
          final result = g.apply(move);
          if (result is! Applied<KlondikeGame>) {
            fail(
              'engine-winnable: a deal marked winnable did not win — base $base, deal #${game.dealNumber.value}: $move refused as $result',
            );
          }
          g = result.game;
        }
        expect(
          g.isWon,
          isTrue,
          reason:
              'engine-winnable: a deal marked winnable did not win — base $base, deal #${game.dealNumber.value} ends unfinished after ${found.solution.length} moves',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 25)));
  }

  test('random deals are never marked winnable', () {
    for (final draw in DrawMode.values) {
      for (var n = 1; n <= 300; n++) {
        final g = KlondikeGame.deal(DealNumber(n), KlondikeOptions(draw: draw));
        expect(
          g.winnable,
          isFalse,
          reason:
              'engine-winnable: deal $n (draw ${draw.count}) is marked winnable without a proof',
        );
        expect(
          g.solution,
          isNull,
          reason: 'engine-winnable: deal $n carries a solution nobody found',
        );
      }
    }
    for (var i = 0; i < 50; i++) {
      final g = KlondikeGame.deal(DealNumber.random());
      expect(
        g.winnable,
        isFalse,
        reason:
            'engine-winnable: a random deal is marked winnable without a proof',
      );
    }
  });
}
