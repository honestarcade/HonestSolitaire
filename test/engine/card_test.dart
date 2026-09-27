import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deck.dart';

void main() {
  test('every card round-trips through its JSON string, both faces', () {
    for (final card in standardDeck()) {
      expect(Card.fromJson(card.toJson()), card);
      expect(Card.fromJson(card.up.toJson()), card.up);
      expect(card.toJson(), endsWith('*'));
      expect(card.up.toJson(), isNot(endsWith('*')));
    }
    expect(const Card(1, Suit.spades, faceUp: true).toJson(), 'AS');
    expect(const Card(10, Suit.hearts, faceUp: true).toJson(), '10H');
    expect(const Card(13, Suit.clubs).toJson(), 'KC*');
  });

  test('hearts and diamonds are red; spades and clubs are black', () {
    expect(const Card(5, Suit.hearts).isRed, isTrue);
    expect(const Card(5, Suit.diamonds).isRed, isTrue);
    expect(const Card(5, Suit.spades).isRed, isFalse);
    expect(const Card(5, Suit.clubs).isBlack, isTrue);
  });

  test('equality covers rank, suit and face', () {
    expect(const Card(7, Suit.spades), const Card(7, Suit.spades));
    expect(
      const Card(7, Suit.spades).hashCode,
      const Card(7, Suit.spades).hashCode,
    );
    expect(const Card(7, Suit.spades), isNot(const Card(7, Suit.clubs)));
    expect(const Card(7, Suit.spades), isNot(const Card(8, Suit.spades)));
    expect(
      const Card(7, Suit.spades),
      isNot(const Card(7, Suit.spades, faceUp: true)),
    );
  });

  test('up and down flip a card and are idempotent', () {
    const down = Card(3, Suit.diamonds);
    expect(down.up.faceUp, isTrue);
    expect(down.up.up, down.up);
    expect(down.up.down, down);
    expect(identical(down.down, down), isTrue);
  });

  test('malformed input throws FormatException', () {
    for (final bad in ['', 'A', '1S', '14S', 'AX', 'A S', 42, null, 'AS**']) {
      expect(() => Card.fromJson(bad), throwsFormatException, reason: '$bad');
    }
  });
}
