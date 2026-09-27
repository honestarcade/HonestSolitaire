/// Number and time formats shared by the top bar and the cards (#78, #80).
library;

import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

/// "m:ss" up to 59:59, then "h:mm:ss"; seconds truncated.
String formatClock(Duration elapsed) {
  final total = elapsed.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h == 0) return '$m:$ss';
  return '$h:${m.toString().padLeft(2, '0')}:$ss';
}

/// Thousands separated by a fixed comma; a leading "−" (U+2212) for negatives.
String formatCount(int n) {
  final digits = n.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return n < 0 ? '−$buffer' : buffer.toString();
}

/// Vegas dollars: "$130", "−$52".
String formatDollars(int n) =>
    n < 0 ? '−\$${formatCount(-n)}' : '\$${formatCount(n)}';

/// The score readout for [game], or null when the game shows no score.
String? formatScore(Game game) => switch (game) {
  KlondikeGame k when k.scoring == ScoringMode.none => null,
  KlondikeGame k when k.scoring == ScoringMode.vegas => formatDollars(k.score),
  _ => formatCount(game.score),
};

/// The readout's prefix: "PTS" or "$" (Vegas), null when there is no score.
String? scoreLabel(Game game) => switch (game) {
  KlondikeGame k when k.scoring == ScoringMode.none => null,
  KlondikeGame k when k.scoring == ScoringMode.vegas => '\$',
  _ => 'PTS',
};

/// Whether the game's clock counts towards its score (the Timed option).
bool isTimed(Game game) => switch (game) {
  KlondikeGame k => k.options.timed,
  SpiderGame s => s.options.timed,
};

/// "Klondike · draw 3", "Spider · 2 suits".
String gameTitle(Game game) => switch (game) {
  KlondikeGame k => 'Klondike · draw ${k.options.draw.count}',
  SpiderGame s =>
    'Spider · ${s.options.suits.count} suit${s.options.suits.count == 1 ? '' : 's'}',
};

/// "Time 1 minute 5 seconds", hours spelled when present.
String spokenTime(Duration elapsed) {
  final total = elapsed.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final parts = <String>[
    if (h > 0) '$h hour${h == 1 ? '' : 's'}',
    if (h > 0 || m > 0) '$m minute${m == 1 ? '' : 's'}',
    '$s second${s == 1 ? '' : 's'}',
  ];
  return 'Time ${parts.join(' ')}';
}

String spokenMoves(int moves) => '$moves move${moves == 1 ? '' : 's'}';

/// "Score 40", "Score minus 52 dollars".
String? spokenScore(Game game) => switch (game) {
  KlondikeGame k when k.scoring == ScoringMode.none => null,
  KlondikeGame k when k.scoring == ScoringMode.vegas =>
    'Score ${k.score < 0 ? 'minus ' : ''}${formatCount(k.score.abs())} dollar${k.score.abs() == 1 ? '' : 's'}',
  _ => 'Score ${formatCount(game.score)}',
};
