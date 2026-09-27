// Shared by the determinism guard and tools/generate_golden_deals.dart: the
// deal-only projection of a game and the modes the golden file pins.
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';

/// The modes the golden file pins, in its order.
const goldenModes = [
  'klondike-draw1',
  'klondike-draw3',
  'spider-1',
  'spider-2',
  'spider-4',
];

/// The deal numbers the golden file pins.
const goldenDeals = [1, 2, 999999];

/// Deals [mode] for [deal] with the engine (strict Spider, default options
/// otherwise).
Game dealFor(String mode, int deal) => switch (mode) {
  'klondike-draw1' => KlondikeGame.deal(DealNumber(deal)),
  'klondike-draw3' => KlondikeGame.deal(
    DealNumber(deal),
    const KlondikeOptions(draw: DrawMode.three),
  ),
  'spider-1' => SpiderGame.deal(DealNumber(deal)),
  'spider-2' => SpiderGame.deal(
    DealNumber(deal),
    const SpiderOptions(suits: SpiderSuits.two),
  ),
  'spider-4' => SpiderGame.deal(
    DealNumber(deal),
    const SpiderOptions(suits: SpiderSuits.four),
  ),
  _ => throw ArgumentError.value(mode, 'mode'),
};

List<String> _pile(List<Card> cards) => [for (final c in cards) c.toJson()];

/// The piles of a game and nothing else: card strings bottom-to-top, empty
/// piles written out, the Spider stock as rows.
Map<String, Object?> projection(Game game) => switch (game) {
  KlondikeGame k => {
    'tableau': [for (final c in k.tableau) _pile(c)],
    'stock': _pile(k.stock),
    'waste': _pile(k.waste),
    'foundations': [for (final f in k.foundations) _pile(f)],
  },
  SpiderGame s => {
    'tableau': [for (final c in s.tableau) _pile(c)],
    'stock': [for (final r in s.stock) _pile(r)],
    'completed': [for (final suit in s.completed) suit.letter],
  },
};

/// Every card in a projection, face state dropped, as strings.
List<String> cardsOf(Map<String, Object?> piles) {
  final out = <String>[];
  void add(Object? pile) {
    for (final c in pile as List) {
      final s = c as String;
      out.add(s.endsWith('*') ? s.substring(0, s.length - 1) : s);
    }
  }

  for (final column in piles['tableau'] as List) {
    add(column);
  }
  final stock = piles['stock'] as List;
  if (stock.isNotEmpty && stock.first is List) {
    for (final row in stock) {
      add(row);
    }
  } else {
    add(stock);
  }
  if (piles.containsKey('waste')) add(piles['waste']);
  if (piles.containsKey('foundations')) {
    for (final f in piles['foundations'] as List) {
      add(f);
    }
  }
  return out..sort();
}
