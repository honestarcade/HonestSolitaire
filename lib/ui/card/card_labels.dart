/// Spoken and printed names for cards. UI-only: the engine never names a
/// card in words.
library;

import 'package:honest_solitaire/engine/card.dart';

const _rankWords = [
  '',
  'Ace',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Jack',
  'Queen',
  'King',
];

extension CardLabels on Card {
  /// "Seven of hearts", "Ace of spades".
  String get spokenName => '${_rankWords[rank]} of ${suit.name}';

  /// "Seven", "Ace".
  String get spokenRank => _rankWords[rank];
}

const faceDownLabel = 'face-down card';
