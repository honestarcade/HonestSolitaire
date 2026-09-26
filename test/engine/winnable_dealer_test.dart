import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

import 'positions.dart';

KlondikeGame replay(KlondikeGame game, List<Move> moves) {
  var g = game;
  for (final move in moves) {
    g = applied(g, move);
  }
  return g;
}

void main() {
  // Expected results recorded 2026-09-26 from a probe run at the default
  // budget: deal 1 solves in draw 1; in draw 3 deals 1–3 are Unknown and
  // deal 4 solves.
  test(
    'a fixed base finds the same deal twice, and its solution wins',
    () async {
      for (var run = 0; run < 2; run++) {
        final events = await WinnableDealer.search(
          DealNumber(1),
          const KlondikeOptions(),
        ).events.toList();
        expect(events.first, isA<Progress>());
        expect(events.last, isA<Found>());
        final found = events.last as Found;
        expect(found.game.dealNumber.value, 1);
        expect(found.game.winnable, isTrue);
        expect(found.game.solution, found.solution);
        expect(
          found.game,
          KlondikeGame.deal(DealNumber(1)),
          reason: 'the same cards as a fresh deal',
        );
        expect(replay(found.game, found.solution).isWon, isTrue);
        for (final event in events.take(events.length - 1)) {
          expect(event, isA<Progress>());
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'draw 3 from base 1 skips to deal 4 and reports each deal tried',
    () async {
      final events = await WinnableDealer.search(
        DealNumber(1),
        const KlondikeOptions(draw: DrawMode.three),
        softLimit: null,
      ).events.toList();
      final found = events.last as Found;
      expect(found.game.dealNumber.value, 4);
      expect(found.game.options.draw, DrawMode.three);
      expect(replay(found.game, found.solution).isWon, isTrue);
      final progress = events.whereType<Progress>().toList();
      expect(progress.last.dealsTried, 4, reason: 'the found deal counts');
      expect(
        progress.map((p) => p.dealsTried),
        containsAllInOrder([1, 2, 3, 4]),
      );
      expect(events.whereType<SoftLimitReached>(), isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'cancel mid-search yields Cancelled within 200 ms and nothing after',
    () async {
      // Deal 2 is Unknown at the default budget, so the worker is busy on it.
      final search = WinnableDealer.search(
        DealNumber(2),
        const KlondikeOptions(),
      );
      final events = <DealerEvent>[];
      final done = Completer<void>();
      search.events.listen(events.add, onDone: done.complete);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final watch = Stopwatch()..start();
      await search.cancel();
      await done.future;
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(200));
      expect(events.last, isA<Cancelled>());
      expect(events.whereType<Found>(), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        events.last,
        isA<Cancelled>(),
        reason: 'nothing follows Cancelled',
      );
      await search.cancel(); // a no-op after the terminal event
    },
  );

  test(
    'a soft limit of zero is reported once and the search still finds',
    () async {
      final events = await WinnableDealer.search(
        DealNumber(1),
        const KlondikeOptions(),
        softLimit: Duration.zero,
      ).events.toList();
      expect(events.whereType<SoftLimitReached>(), hasLength(1));
      expect(events.last, isA<Found>());
      final soft = events.indexWhere((e) => e is SoftLimitReached);
      expect(
        events[soft - 1],
        isA<Progress>(),
        reason: 'progress precedes the soft limit',
      );
      expect(events.indexWhere((e) => e is Found), greaterThan(soft));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('winnable is false on every public way to make a game', () {
    final deal = KlondikeGame.deal(DealNumber(1));
    expect(deal.winnable, isFalse);
    expect(deal.solution, isNull);
    expect(deal.restart().winnable, isFalse);
    final drawn = applied(deal, const Draw());
    expect(drawn.winnable, isFalse);
    expect(
      (drawn.undo(unlimited: true) as Applied<KlondikeGame>).game.winnable,
      isFalse,
    );
    expect(
      klondike(tableau: [cards('AS'), [], [], [], [], [], []]).winnable,
      isFalse,
    );
    expect(
      KlondikeGame.deal(
        DealNumber(4),
        const KlondikeOptions(draw: DrawMode.three),
      ).winnable,
      isFalse,
    );
  });

  test('a found game keeps winnable and its solution through play, undo and restart', () async {
    final events = await WinnableDealer.search(
      DealNumber(1),
      const KlondikeOptions(),
      softLimit: null,
    ).events.toList();
    final found = (events.last as Found).game;
    final played = applied(found, found.solution!.first);
    expect(played.winnable, isTrue);
    expect(played.solution, found.solution);
    expect(
      (played.undo(unlimited: true) as Applied<KlondikeGame>).game.winnable,
      isTrue,
    );
    expect(found.restart().winnable, isTrue);
    expect(found.restart().solution, found.solution);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a bad budget throws', () {
    expect(
      () => WinnableDealer.search(
        DealNumber(1),
        const KlondikeOptions(),
        nodeBudget: 0,
      ),
      throwsArgumentError,
    );
  });
}
