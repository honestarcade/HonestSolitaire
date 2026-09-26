/// Cards and suits — the engine's smallest values.
///
/// The engine is pure Dart (see `test/guards/engine_imports_test.dart`), so a
/// card carries no rendering detail: rank, suit and which way up it lies.
library;

/// The four suits, declared in the design's ♠♥♦♣ order. Every unshuffled deck
/// follows this order suit-major, ace to king, and Klondike's foundations sit
/// in it left to right.
enum Suit {
  spades('S', '♠'),
  hearts('H', '♥'),
  diamonds('D', '♦'),
  clubs('C', '♣');

  const Suit(this.letter, this.symbol);

  /// The one-letter code used in the compact JSON form.
  final String letter;

  /// The glyph the design draws.
  final String symbol;

  bool get isRed => this == hearts || this == diamonds;

  static Suit fromLetter(String letter) {
    for (final suit in values) {
      if (suit.letter == letter) return suit;
    }
    throw FormatException('unknown suit letter "$letter"');
  }
}

/// Rank names for the compact JSON form and for the board: index 1 is the ace.
const List<String> rankNames = [
  '',
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];

const int aceRank = 1;
const int kingRank = 13;

/// An immutable playing card. Equality covers rank, suit and face state; a
/// card has no identity of its own, so two aces of spades are equal.
class Card {
  const Card(this.rank, this.suit, {this.faceUp = false})
    : assert(rank >= aceRank && rank <= kingRank, 'rank must be 1..13');

  /// 1 (ace) .. 13 (king).
  final int rank;
  final Suit suit;
  final bool faceUp;

  bool get isRed => suit.isRed;
  bool get isBlack => !suit.isRed;
  bool get isAce => rank == aceRank;
  bool get isKing => rank == kingRank;

  /// The rank as the design prints it: `A`, `2`..`10`, `J`, `Q`, `K`.
  String get rankName => rankNames[rank];

  /// The same card turned face up.
  Card get up => faceUp ? this : Card(rank, suit, faceUp: true);

  /// The same card turned face down.
  Card get down => faceUp ? Card(rank, suit) : this;

  /// The compact JSON form: rank name, suit letter, and a trailing `*` when
  /// the card is face down — `"AS"`, `"10H"`, `"KC*"`.
  String toJson() => '$rankName${suit.letter}${faceUp ? '' : '*'}';

  /// Parses [toJson]'s form. Throws [FormatException] on anything else.
  factory Card.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('a card must be a string, not $json');
    }
    var text = json;
    var faceUp = true;
    if (text.endsWith('*')) {
      faceUp = false;
      text = text.substring(0, text.length - 1);
    }
    if (text.length < 2) throw FormatException('malformed card "$json"');
    final suit = Suit.fromLetter(text.substring(text.length - 1));
    final rank = rankNames.indexOf(text.substring(0, text.length - 1));
    if (rank < aceRank) throw FormatException('malformed card "$json"');
    return Card(rank, suit, faceUp: faceUp);
  }

  @override
  bool operator ==(Object other) =>
      other is Card &&
      other.rank == rank &&
      other.suit == suit &&
      other.faceUp == faceUp;

  @override
  int get hashCode => Object.hash(rank, suit, faceUp);

  @override
  String toString() => toJson();
}
