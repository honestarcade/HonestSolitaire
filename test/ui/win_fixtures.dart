import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../engine/positions.dart';

/// All face up, stock empty, one card on the waste: moving it makes the
/// board solved.
final oneMoveFromSolved = klondike(
  tableau: [
    cards('KC QD JC 10D'),
    cards('KD QC JD 10C 9D 8C'),
    cards('9C 8D 7C 6D'),
    [],
    cards('7D 6C 5D 4C 3D 2C'),
    cards('5C 4D 3C 2D'),
    cards('AD'),
  ],
  waste: cards('AC'),
  foundations: [suitRun(Suit.spades, 13), suitRun(Suit.hearts, 13), [], []],
);

KlondikeGame nearWin(KlondikeOptions options) => klondike(
  tableau: [cards('KC'), [], [], [], [], [], []],
  foundations: [
    suitRun(Suit.spades, 13),
    suitRun(Suit.hearts, 13),
    suitRun(Suit.diamonds, 13),
    suitRun(Suit.clubs, 12),
  ],
  options: options,
  moveScore: options.scoring == ScoringMode.vegas ? 40 : 100,
  elapsed: const Duration(seconds: 120),
  dealNumber: 48213,
);
