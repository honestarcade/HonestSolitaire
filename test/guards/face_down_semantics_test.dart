@Tags(['guard'])
library;

// A column's face-down cards are one TalkBack node that never names a rank
// or a suit (#108, owner): a label that did would tell a screen-reader
// player what a sighted one cannot see. Every count, every column, the 13
// rank words and the 4 suit words as whole words, case-insensitively.

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/ui/board/board_semantics.dart';

const rankWords = [
  'ace',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'jack',
  'queen',
  'king',
];
const suitWords = ['spades', 'hearts', 'diamonds', 'clubs'];

void main() {
  test('the face-down column label names no rank and no suit', () {
    final deck = standardDeck();
    final offenders = <String>[];
    for (var column = 0; column < 10; column++) {
      for (var count = 1; count <= 13; count++) {
        final down = deck.sublist(0, count).map((c) => c.down).toList();
        final label = faceDownColumnLabel(column, down).toLowerCase();
        for (final word in [...rankWords, ...suitWords]) {
          if (RegExp('\\b$word\\b').hasMatch(label)) {
            offenders.add('"$label" names $word');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'face-down: ${offenders.length} label(s) give a card away\n'
          '${offenders.take(5).join('\n')}',
    );
  });

  test('the label says how many and where', () {
    final deck = standardDeck();
    expect(
      faceDownColumnLabel(2, [deck.first.down]),
      'Column 3, 1 face-down card',
    );
    expect(
      faceDownColumnLabel(0, deck.sublist(0, 4).map((c) => c.down).toList()),
      'Column 1, 4 face-down cards',
    );
  });
}
