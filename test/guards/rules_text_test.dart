@Tags(['guard'])
library;

// The How to play text states scoring numbers in words (#90). Each
// RuleCard.numbers pair names an engine constant and the value the text
// claims; this guard holds the two together, checks the value is actually
// written in the card, and checks the pairs cover every scoring constant
// #62/#63 define, so a rule change cannot leave the text behind.
//
// The time-bonus constants (timeBonusNumerator, minimumBonusSeconds) are
// described without numbers ("a bonus that is bigger the faster you
// finish") and are not covered — by design, said here so the omission is
// deliberate.

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/content/rules_text.dart';

/// The engine's value for each name the text may cite.
final engineValues = <String, int>{
  for (final e in KlondikeScoreEvent.values)
    if (e != KlondikeScoreEvent.deal)
      'KlondikeScoring.standard.${e.name}': KlondikeScoring.standard.delta(e),
  'KlondikeScoring.standard.floor': KlondikeScoring.standard.floor!,
  'KlondikeScoring.vegas.deal': KlondikeScoring.vegas.delta(
    KlondikeScoreEvent.deal,
  ),
  'KlondikeScoring.vegas.toFoundation': KlondikeScoring.vegas.delta(
    KlondikeScoreEvent.toFoundation,
  ),
  'KlondikeScoring.vegas.foundationToTableau': KlondikeScoring.vegas.delta(
    KlondikeScoreEvent.foundationToTableau,
  ),
  'KlondikeScoring.timePenaltyPoints': KlondikeScoring.timePenaltyPoints,
  'KlondikeScoring.timePenaltyPeriod.inSeconds':
      KlondikeScoring.timePenaltyPeriod.inSeconds,
  'SpiderScoring.atDeal': SpiderScoring.atDeal,
  'SpiderScoring.perMove': SpiderScoring.perMove,
  'SpiderScoring.perRun': SpiderScoring.perRun,
  'SpiderScoring.floor': SpiderScoring.floor,
};

/// The word the text uses for a magnitude; only the values the rules need.
String numberWords(int n) => switch (n) {
  0 => 'zero',
  1 => 'one',
  2 => 'two',
  5 => 'five',
  10 => 'ten',
  15 => 'fifteen',
  52 => 'fifty-two',
  100 => 'one hundred',
  500 => 'five hundred',
  _ => throw ArgumentError.value(n, 'n', 'add its words to the test'),
};

void main() {
  final cards = [...klondikeRules, ...spiderRules];

  test('every number the text states equals the engine constant', () {
    for (final card in cards) {
      for (final (name, value) in card.numbers) {
        expect(
          engineValues.containsKey(name),
          isTrue,
          reason:
              'rules-text: $name is not an engine constant this guard knows',
        );
        expect(
          value,
          engineValues[name],
          reason: 'rules-text: $name drifted from the engine',
        );
      }
    }
  });

  test('every stated number is written in words in its card', () {
    for (final card in cards) {
      final body = card.body.toLowerCase();
      for (final (name, value) in card.numbers) {
        expect(
          body,
          contains(numberWords(value.abs())),
          reason: 'rules-text: $name is not stated in words in ${card.tag}',
        );
      }
    }
  });

  test('the text covers every scoring constant', () {
    final stated = {
      for (final card in cards)
        for (final (name, _) in card.numbers) name,
    };
    expect(
      stated,
      engineValues.keys.toSet(),
      reason:
          'rules-text: a scoring constant is not stated, or a stated '
          'name is unknown',
    );
    // The zero-delta events are not stated by design; the sets above
    // still hold them so a delta that becomes non-zero is noticed.
  });
}
