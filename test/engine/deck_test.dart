import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/rng.dart';

Map<Suit, int> _bySuit(List<Card> cards) {
  final counts = {for (final s in Suit.values) s: 0};
  for (final c in cards) {
    counts[c.suit] = counts[c.suit]! + 1;
  }
  return counts;
}

void main() {
  test('the standard deck is 52 distinct face-down cards in suit order', () {
    final deck = standardDeck();
    expect(deck, hasLength(52));
    expect(deck.toSet(), hasLength(52));
    expect(deck.every((c) => !c.faceUp), isTrue);
    expect(deck.first, const Card(1, Suit.spades));
    expect(deck[13], const Card(1, Suit.hearts));
    expect(deck.last, const Card(13, Suit.clubs));
    expect(_bySuit(deck), {for (final s in Suit.values) s: 13});
  });

  test('spider decks hold 104 cards in the right suit composition', () {
    expect(_bySuit(spiderDeck(SpiderSuits.one)), {
      Suit.spades: 104,
      Suit.hearts: 0,
      Suit.diamonds: 0,
      Suit.clubs: 0,
    });
    expect(_bySuit(spiderDeck(SpiderSuits.two)), {
      Suit.spades: 52,
      Suit.hearts: 52,
      Suit.diamonds: 0,
      Suit.clubs: 0,
    });
    expect(_bySuit(spiderDeck(SpiderSuits.four)), {
      for (final s in Suit.values) s: 26,
    });
    for (final suits in SpiderSuits.values) {
      final deck = spiderDeck(suits);
      expect(deck, hasLength(104));
      expect(deck.every((c) => !c.faceUp), isTrue);
      for (var rank = 1; rank <= 13; rank++) {
        expect(deck.where((c) => c.rank == rank), hasLength(8));
      }
    }
  });

  test('spider copies are blocked suit by suit, ace to king', () {
    final deck = spiderDeck(SpiderSuits.two);
    expect(deck[0], const Card(1, Suit.spades));
    expect(deck[12], const Card(13, Suit.spades));
    expect(deck[13], const Card(1, Suit.spades));
    expect(deck[52], const Card(1, Suit.hearts));
  });

  test('SpiderSuits.fromCount accepts 1, 2, 4 only', () {
    expect(SpiderSuits.fromCount(1), SpiderSuits.one);
    expect(SpiderSuits.fromCount(4), SpiderSuits.four);
    expect(() => SpiderSuits.fromCount(3), throwsArgumentError);
  });

  test('the same deal number always produces the same shuffled deck', () {
    final a = shuffle(standardDeck(), Rng(DealNumber(4242).value));
    final b = shuffle(standardDeck(), Rng(DealNumber(4242).value));
    expect(a, b);
    expect(a, isNot(shuffle(standardDeck(), Rng(DealNumber(4243).value))));
  });

  test('deal numbers are 1..999999 and random ones stay in range', () {
    expect(DealNumber(1).value, 1);
    expect(DealNumber(999999).value, 999999);
    expect(() => DealNumber(0), throwsArgumentError);
    expect(() => DealNumber(1000000), throwsArgumentError);
    expect(() => DealNumber(-5), throwsArgumentError);
    for (var i = 0; i < 1000; i++) {
      expect(DealNumber.random().value, inInclusiveRange(1, 999999));
    }
    expect(DealNumber(999999).next.value, 1);
    expect(DealNumber(41).next.value, 42);
  });
}
