@Tags(['guard'])
library;

// Invariant 3: deals are generated on the device, from a seed,
// deterministically (#70).
//
// The golden file pins the full deal for three numbers in every mode; the
// engine regenerates each and must match pile for pile. Over 1..300 every
// deal must be a permutation of the right deck with the right shape, and a
// fresh isolate must deal the same cards as this one.
//
// What this does not cover: deal numbers beyond the sampled ones (the
// algorithm is the same code path, but only these are asserted), Spider
// winnability (not offered), and the uniformity of a random deal (not
// measured — honor-system, see CLAUDE.md invariant 4).

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../../integration_test/golden_deals.g.dart';
import 'engine_golden.dart';
import 'repo_files.dart';

/// The sorted card strings of the deck each mode deals, written out rather
/// than taken from the deck builders, so a builder bug cannot agree with
/// itself.
List<String> expectedDeck(String mode) {
  const ranks = [
    'A',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
  ];
  final copies = switch (mode) {
    'klondike-draw1' || 'klondike-draw3' => {'S': 1, 'H': 1, 'D': 1, 'C': 1},
    'spider-1' => {'S': 8},
    'spider-2' => {'S': 4, 'H': 4},
    'spider-4' => {'S': 2, 'H': 2, 'D': 2, 'C': 2},
    _ => throw ArgumentError(mode),
  };
  return [
    for (final entry in copies.entries)
      for (var copy = 0; copy < entry.value; copy++)
        for (final rank in ranks) '$rank${entry.key}',
  ]..sort();
}

/// The first pile that differs between [a] and [b], or null.
String? firstDifference(Map<String, Object?> a, Map<String, Object?> b) {
  for (final key in a.keys) {
    final x = jsonEncode(a[key]);
    final y = jsonEncode(b[key]);
    if (x != y) {
      final xs = a[key];
      if (xs is List && xs.isNotEmpty && xs.first is List) {
        final ys = b[key] as List;
        for (var i = 0; i < xs.length; i++) {
          if (jsonEncode(xs[i]) != jsonEncode(ys[i])) return '$key[$i]';
        }
      }
      return key;
    }
  }
  return null;
}

void checkShape(String mode, Map<String, Object?> piles, String what) {
  final tableau = (piles['tableau'] as List).cast<List>();
  if (mode.startsWith('klondike')) {
    expect(tableau, hasLength(7), reason: '$what: seven columns');
    for (var c = 0; c < 7; c++) {
      expect(
        tableau[c],
        hasLength(c + 1),
        reason: '$what: column $c holds ${c + 1}',
      );
      for (var i = 0; i < c; i++) {
        expect(
          tableau[c][i],
          endsWith('*'),
          reason: '$what: column $c card $i face down',
        );
      }
      expect(
        tableau[c].last,
        isNot(endsWith('*')),
        reason: '$what: column $c top face up',
      );
    }
    expect(piles['stock'], hasLength(24), reason: '$what: stock 24');
    expect(
      (piles['stock'] as List).every((c) => (c as String).endsWith('*')),
      isTrue,
      reason: '$what: stock face down',
    );
    expect(piles['waste'], isEmpty, reason: '$what: waste empty');
    expect(
      (piles['foundations'] as List).every((f) => (f as List).isEmpty),
      isTrue,
      reason: '$what: foundations empty',
    );
  } else {
    expect(tableau, hasLength(10), reason: '$what: ten columns');
    for (var c = 0; c < 10; c++) {
      expect(
        tableau[c],
        hasLength(c < 4 ? 6 : 5),
        reason: '$what: column $c height',
      );
      for (var i = 0; i < tableau[c].length - 1; i++) {
        expect(
          tableau[c][i],
          endsWith('*'),
          reason: '$what: column $c card $i face down',
        );
      }
      expect(
        tableau[c].last,
        isNot(endsWith('*')),
        reason: '$what: column $c top face up',
      );
    }
    final stock = (piles['stock'] as List).cast<List>();
    expect(stock, hasLength(5), reason: '$what: five stock rows');
    for (final row in stock) {
      expect(row, hasLength(10), reason: '$what: rows of ten');
      expect(
        row.every((c) => (c as String).endsWith('*')),
        isTrue,
        reason: '$what: stock face down',
      );
    }
    expect(piles['completed'], isEmpty, reason: '$what: no completed runs');
  }
}

void main() {
  final golden = jsonDecode(
    readFile('test/fixtures/golden_deals.json'),
  ) as Map<String, Object?>;
  final records = (golden['deals'] as List).cast<Map<String, Object?>>();

  group('the golden file', () {
    test('pins every mode and deal number exactly once', () {
      final keys = [for (final r in records) '${r['mode']}#${r['deal']}'];
      expect(
        keys..sort(),
        [
          for (final m in goldenModes)
            for (final d in goldenDeals) '$m#$d',
        ]..sort(),
        reason:
            'engine-determinism: the golden file does not pin the planned set',
      );
    });

    for (final record in records) {
      final mode = record['mode'] as String;
      final deal = record['deal'] as int;
      final piles = record['piles'] as Map<String, Object?>;

      test('$mode deal $deal is a valid deck with the right shape', () {
        expect(
          cardsOf(piles),
          expectedDeck(mode),
          reason:
              'engine-determinism: the golden for $mode deal $deal is not a valid deck',
        );
        checkShape(mode, piles, 'engine-determinism: golden $mode deal $deal');
      });

      test('$mode deal $deal is dealt as pinned', () {
        final now = projection(dealFor(mode, deal));
        final differing = firstDifference(piles, now);
        expect(
          differing,
          isNull,
          reason:
              'engine-determinism: $mode deal $deal differs from '
              'test/fixtures/golden_deals.json at pile $differing. The same '
              'deal number no longer deals the same cards. Regenerating the '
              'golden (tools/generate_golden_deals.dart) is a deliberate act '
              'that changes every player\'s deals, not a fix.',
        );
      });
    }

    test('the on-device copy matches the golden file', () {
      final drifted = <String>[
        for (final r in records)
          if (goldenDealPiles[r['mode']]?[r['deal']] != jsonEncode(r['piles']))
            '${r['mode']} deal ${r['deal']}',
        for (final MapEntry(key: mode, value: deals) in goldenDealPiles.entries)
          for (final deal in deals.keys)
            if (!records.any((r) => r['mode'] == mode && r['deal'] == deal))
              '$mode deal $deal (not in the JSON)',
      ];
      expect(
        drifted,
        isEmpty,
        reason:
            'engine-determinism: integration_test/golden_deals.g.dart drifted '
            'from test/fixtures/golden_deals.json at $drifted; regenerate both '
            'with tools/generate_golden_deals.dart',
      );
    });

    test('draw 1 and draw 3 pin the same cards', () {
      for (final deal in goldenDeals) {
        final one = records.firstWhere(
          (r) => r['mode'] == 'klondike-draw1' && r['deal'] == deal,
        );
        final three = records.firstWhere(
          (r) => r['mode'] == 'klondike-draw3' && r['deal'] == deal,
        );
        expect(
          jsonEncode(one['piles']),
          jsonEncode(three['piles']),
          reason:
              'engine-determinism: deal $deal lays out different cards in draw 1 and draw 3',
        );
      }
    });
  });

  group('deals 1..300', () {
    for (final mode in goldenModes) {
      test('$mode: every deal is the right deck with the right shape, twice', () {
        for (var n = 1; n <= 300; n++) {
          final a = projection(dealFor(mode, n));
          expect(
            cardsOf(a),
            expectedDeck(mode),
            reason:
                'engine-determinism: $mode deal $n is not a permutation of its deck',
          );
          checkShape(mode, a, 'engine-determinism: $mode deal $n');
          final b = projection(dealFor(mode, n));
          expect(
            jsonEncode(b),
            jsonEncode(a),
            reason:
                'engine-determinism: $mode deal $n dealt twice gave different cards',
          );
        }
      });

      test('$mode: a fresh isolate deals 1..300 identically', () async {
        final here = [
          for (var n = 1; n <= 300; n++)
            jsonEncode(projection(dealFor(mode, n))),
        ];
        final there = await Isolate.run(
          () => [
            for (var n = 1; n <= 300; n++)
              jsonEncode(projection(dealFor(mode, n))),
          ],
        );
        for (var n = 1; n <= 300; n++) {
          expect(
            there[n - 1],
            here[n - 1],
            reason:
                'engine-determinism: $mode deal $n differs between isolates — the shuffle reads process state',
          );
        }
      });
    }

    test('deal numbers 1..300 are all different deals', () {
      final seen = <String>{};
      for (var n = 1; n <= 300; n++) {
        expect(
          seen.add(jsonEncode(projection(KlondikeGame.deal(DealNumber(n))))),
          isTrue,
          reason: 'engine-determinism: deal $n repeats an earlier deal',
        );
      }
    });
  });

  test('the suit order and card strings the golden relies on are fixed', () {
    expect(
      Suit.values.map((s) => s.letter).toList(),
      ['S', 'H', 'D', 'C'],
      reason: 'engine-determinism: the suit order changed, which reorders every unshuffled deck',
    );
    expect(const Card(10, Suit.hearts, faceUp: true).toJson(), '10H');
    expect(const Card(1, Suit.spades).toJson(), 'AS*');
  });
}
