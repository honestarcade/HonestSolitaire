// Regenerates test/fixtures/golden_deals.json — a deliberate act.
//
// The golden pins the deal for numbers 1, 2 and 999999 in every mode so
// test/guards/engine_determinism_test.dart can prove the shuffle has not
// changed. Run it only when the deal algorithm is meant to change, and say
// so in the commit that carries the new file:
//
//   dart run tools/generate_golden_deals.dart
import 'dart:convert';
import 'dart:io';

import '../test/guards/engine_golden.dart';

void main() {
  final records = [
    for (final mode in goldenModes)
      for (final deal in goldenDeals)
        {'mode': mode, 'deal': deal, 'piles': projection(dealFor(mode, deal))},
  ];
  final text = const JsonEncoder.withIndent('  ').convert({
    'note':
        'Deal-only projections produced by lib/engine (the #59 shuffle whose '
        'first outputs test/engine/rng_test.dart pins). Regenerate with '
        'tools/generate_golden_deals.dart, deliberately.',
    'deals': records,
  });
  File('test/fixtures/golden_deals.json').writeAsStringSync('$text\n');
  stdout.writeln(
    'wrote ${records.length} records to test/fixtures/golden_deals.json',
  );
}
