// Position builders shared by the engine tests.
//
// A test names only the piles it cares about; the cards it does not mention
// are dumped face down at the bottom of one column (`dump`), where they
// affect nothing a test asserts, so `fromPiles`' completeness check holds.
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';

/// `c('7H')` is the seven of hearts face up; `c('7H*')` face down.
Card c(String text) => Card.fromJson(text);

/// `cards('AS 2H* KC')`, bottom to top.
List<Card> cards(String text) => text.trim().isEmpty
    ? []
    : text.trim().split(RegExp(r'\s+')).map(c).toList();

/// Ace to [count] of [suit], face up: a foundation pile.
List<Card> suitRun(Suit suit, int count) => [
  for (var rank = 1; rank <= count; rank++) Card(rank, suit, faceUp: true),
];

/// King down to [lowest] of [suit], face up: a tableau run.
List<Card> kingDown(Suit suit, int lowest) => [
  for (var rank = 13; rank >= lowest; rank--) Card(rank, suit, faceUp: true),
];

/// A Klondike position. Unmentioned cards go face down under column [dump].
KlondikeGame klondike({
  required List<List<Card>> tableau,
  List<Card> stock = const [],
  List<Card> waste = const [],
  List<List<Card>>? foundations,
  KlondikeOptions options = const KlondikeOptions(),
  int dump = 6,
  int? dealNumber,
  int? moveScore,
  int moves = 0,
  Duration elapsed = Duration.zero,
}) {
  foundations ??= [[], [], [], []];
  final used = <Card>{
    for (final col in tableau) ...col.map((x) => x.down),
    ...stock.map((x) => x.down),
    ...waste.map((x) => x.down),
    for (final f in foundations) ...f.map((x) => x.down),
  };
  final rest = standardDeck().where((x) => !used.contains(x)).toList();
  final full = List<List<Card>>.of(tableau);
  full[dump] = [...rest, ...tableau[dump]];
  return KlondikeGame.fromPiles(
    tableau: full,
    stock: stock,
    waste: waste,
    foundations: foundations,
    options: options,
    dealNumber: dealNumber == null ? null : DealNumber(dealNumber),
    moveScore: moveScore,
    moves: moves,
    elapsed: elapsed,
  );
}

/// A Spider position. Unmentioned cards go face down under column [dump].
SpiderGame spider({
  required List<List<Card>> tableau,
  List<List<Card>> stock = const [],
  List<Suit> completed = const [],
  SpiderOptions options = const SpiderOptions(),
  int dump = 9,
  int? dealNumber,
  int moveScore = 500,
  int moves = 0,
  Duration elapsed = Duration.zero,
}) {
  final pool = spiderDeck(options.suits);
  final used = [
    for (final col in tableau) ...col.map((x) => x.down),
    for (final row in stock) ...row.map((x) => x.down),
    for (final suit in completed)
      for (var rank = 1; rank <= 13; rank++) Card(rank, suit),
  ];
  final rest = List<Card>.of(pool);
  for (final card in used) {
    if (!rest.remove(card)) {
      throw ArgumentError('$card is used more often than the deck holds');
    }
  }
  final full = List<List<Card>>.of(tableau);
  full[dump] = [...rest, ...tableau[dump]];
  return SpiderGame.fromPiles(
    tableau: full,
    stock: stock,
    completed: completed,
    options: options,
    dealNumber: dealNumber == null ? null : DealNumber(dealNumber),
    moveScore: moveScore,
    moves: moves,
    elapsed: elapsed,
  );
}

/// Applies [move] and fails the test on a refusal.
G applied<G extends Game>(G game, Move move) {
  final result = game.apply(move);
  if (result is Applied<G>) return result.game;
  fail('$move was refused: $result on\n$game');
}

/// Applies [move] and returns the refusal reason, failing on success.
RefusalReason refused(Game game, Move move) {
  final result = game.apply(move);
  if (result is Refused) return result.reason;
  fail('$move was applied, expected a refusal, on\n$game');
}
