/// The design's DISPLAY settings, as an immutable value the board listens to.
library;

import '../card/card_style.dart';

class DisplayOptions {
  const DisplayOptions({
    this.leftHanded = false,
    this.largeCards = false,
    this.cardBack = CardBack.navy,
    this.showTimer = true,
    this.showMovesAndScore = true,
  });

  final bool leftHanded;
  final bool largeCards;
  final CardBack cardBack;
  final bool showTimer;
  final bool showMovesAndScore;

  DisplayOptions copyWith({
    bool? leftHanded,
    bool? largeCards,
    CardBack? cardBack,
    bool? showTimer,
    bool? showMovesAndScore,
  }) => DisplayOptions(
    leftHanded: leftHanded ?? this.leftHanded,
    largeCards: largeCards ?? this.largeCards,
    cardBack: cardBack ?? this.cardBack,
    showTimer: showTimer ?? this.showTimer,
    showMovesAndScore: showMovesAndScore ?? this.showMovesAndScore,
  );

  @override
  bool operator ==(Object other) =>
      other is DisplayOptions &&
      other.leftHanded == leftHanded &&
      other.largeCards == largeCards &&
      other.cardBack == cardBack &&
      other.showTimer == showTimer &&
      other.showMovesAndScore == showMovesAndScore;

  @override
  int get hashCode => Object.hash(
    leftHanded,
    largeCards,
    cardBack,
    showTimer,
    showMovesAndScore,
  );

  @override
  String toString() =>
      'DisplayOptions(leftHanded $leftHanded, largeCards $largeCards, '
      '${cardBack.name} back, showTimer $showTimer, showMovesAndScore $showMovesAndScore)';
}
