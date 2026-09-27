/// Unshuffled decks: the 52 cards of Klondike and the 104 of Spider.
///
/// Order is fixed by `Suit`'s declaration — suit-major, ace to king — and
/// Spider's copies are blocked, all copies of a suit's run together, suit by
/// suit. That order is what a deal number's shuffle starts from, so it is
/// part of what makes deals deterministic.
library;

import 'card.dart';

/// How many suits a Spider deal uses. Two decks always: 104 cards.
enum SpiderSuits {
  one(1),
  two(2),
  four(4);

  const SpiderSuits(this.count);

  final int count;

  /// The suits in play, in `Suit` order.
  List<Suit> get suits => Suit.values.take(count).toList(growable: false);

  /// Copies of each suit's ace-to-king run: 8, 4 or 2.
  int get copies => 8 ~/ count;

  static SpiderSuits fromCount(int count) {
    for (final s in values) {
      if (s.count == count) return s;
    }
    throw ArgumentError.value(count, 'count', 'must be 1, 2 or 4');
  }
}

/// The 52 cards of one deck, face down, each carrying its index as its id.
List<Card> standardDeck() => [
  for (final suit in Suit.values)
    for (var rank = aceRank; rank <= kingRank; rank++)
      Card(rank, suit, id: suit.index * kingRank + rank - 1),
];

/// The 104 cards of a Spider deal in [suits] suits, face down: 8×13 spades;
/// 4×13 each of spades and hearts; or 2×13 of every suit. Ids are indices.
List<Card> spiderDeck(SpiderSuits suits) {
  final out = <Card>[];
  for (final suit in suits.suits) {
    for (var copy = 0; copy < suits.copies; copy++) {
      for (var rank = aceRank; rank <= kingRank; rank++) {
        out.add(Card(rank, suit, id: out.length));
      }
    }
  }
  return out;
}

/// Gives every card in [piles] the id of a matching card of [deck] (#99):
/// pile by pile, card by card, the first unused deck card of that rank and
/// suit, so Spider's duplicates are told apart by occurrence order.
/// [reserved] cards (a completed run) take their ids first. A card with no
/// match keeps its own id.
List<List<Card>> identifyPiles(
  List<Card> deck,
  List<List<Card>> piles, {
  Iterable<Card> reserved = const [],
}) {
  final used = List<bool>.filled(deck.length, false);
  Card take(Card card) {
    for (var i = 0; i < deck.length; i++) {
      if (!used[i] && deck[i].rank == card.rank && deck[i].suit == card.suit) {
        used[i] = true;
        return card.withId(i);
      }
    }
    return card;
  }

  for (final card in reserved) {
    take(card);
  }
  return [
    for (final pile in piles) [for (final card in pile) take(card)],
  ];
}
