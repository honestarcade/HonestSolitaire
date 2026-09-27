/// What TalkBack reads on the board (#108): the label of every card and
/// pile, the sentence for every step, refusal and hint, and the custom
/// actions a card offers — the engine's `legalMoves` in words. Pure
/// functions over the game; the board places them at its layout's rects.
library;

import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart' as engine;

import '../card/card_labels.dart';
import 'pile_ref.dart';

/// "top card", "2nd from top", "3rd from top", "4th from top" …
String ordinal(int fromTop) => switch (fromTop) {
  0 => 'top card',
  1 => '2nd from top',
  2 => '3rd from top',
  _ => '${fromTop + 1}th from top',
};

/// "1 card", "2 cards".
String plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

String capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String columnName(int column) => 'column ${column + 1}';

String foundationName(Suit suit) => '${suit.name} foundation';

String pileName(BoardPile pile) => switch (pile) {
  TableauPile(:final column) => columnName(column),
  FoundationPile(:final suit) => foundationName(suit),
  WastePile() => 'waste',
  StockPile() => 'stock',
  CompletedPile() => 'completed runs',
};

/// "Seven of hearts, column 3, top card" / "…, 2nd from top"; on the
/// waste "…, waste, top card"; on a foundation "…, hearts foundation".
String cardLabel(
  Card card,
  BoardPile pile, {
  required int fromTop,
  bool selected = false,
  bool hinted = false,
}) {
  final place = switch (pile) {
    FoundationPile(:final suit) => foundationName(suit),
    _ => '${pileName(pile)}, ${ordinal(fromTop)}',
  };
  return '${card.spokenName}, $place'
      '${selected ? ', selected' : ''}${hinted ? ', hinted' : ''}';
}

/// One node for a column's face-down cards: "Column 3, 4 face-down cards".
/// Never a rank or a suit (owner, round two): the guard holds it to that.
String faceDownColumnLabel(int column, List<Card> down) =>
    '${capital(columnName(column))}, ${plural(down.length, 'face-down card')}';

String emptyColumnLabel(int column) => '${capital(columnName(column))}, empty';

String stockLabel(KlondikeGame k, {bool hinted = false}) {
  final base = k.stock.isNotEmpty
      ? 'Stock, ${plural(k.stock.length, 'card')}'
      : k.waste.isNotEmpty
      ? 'Stock, empty, double-tap to recycle'
      : 'Stock, empty';
  return hinted ? '$base, hinted' : base;
}

String spiderStockLabel(SpiderGame s, {bool hinted = false}) {
  final base = s.rowsLeft == 0
      ? 'Stock, no deals left'
      : 'Stock, ${plural(s.rowsLeft, 'deal')} left';
  return hinted ? '$base, hinted' : base;
}

String wasteLabel(KlondikeGame k) => k.waste.isEmpty
    ? 'Waste, empty'
    : 'Waste, ${plural(k.waste.length, 'card')}';

String foundationLabel(Suit suit, List<Card> cards) {
  final name = capital(foundationName(suit));
  if (cards.isEmpty) return '$name, empty';
  if (cards.length == kingRank) return '$name, complete';
  return '$name, up to ${cards.last.spokenRank.toLowerCase()}';
}

String completedLabel(SpiderGame s) =>
    'Completed runs, ${s.completed.length} of $spiderRunsToWin';

/// "Seven of hearts" / "Seven of hearts and 2 more".
String runWords(List<Card> run) => run.length == 1
    ? run.first.spokenName
    : '${run.first.spokenName} and ${run.length - 1} more';

/// The move alone: "Seven of hearts to column 3", "Drew four of clubs" …
String describeMove(Game before, Move move, Game after) {
  switch (move) {
    case MoveRun(:final from, :final start, :final to):
      final run = (before as KlondikeGame).tableau[from].sublist(start);
      return '${runWords(run)} to ${columnName(to)}';
    case MoveCards(:final from, :final start, :final to):
      final run = (before as SpiderGame).tableau[from].sublist(start);
      return '${runWords(run)} to ${columnName(to)}';
    case WasteToTableau(:final to):
      final k = before as KlondikeGame;
      return '${k.waste.last.spokenName} to ${columnName(to)}';
    case WasteToFoundation():
      final card = (before as KlondikeGame).waste.last;
      return '${card.spokenName} to ${foundationName(card.suit)}';
    case TableauToFoundation(:final from):
      final card = (before as KlondikeGame).tableau[from].last;
      return '${card.spokenName} to ${foundationName(card.suit)}';
    case FoundationToTableau(:final foundation, :final to):
      final card = (before as KlondikeGame).foundations[foundation].last;
      return '${card.spokenName} to ${columnName(to)}';
    case Draw():
      // Draw three: the new top only.
      return 'Drew ${lower((after as KlondikeGame).waste.last.spokenName)}';
    case Recycle():
      return 'Stock recycled';
    case DealRow():
      return 'Dealt a row, ${(after as SpiderGame).rowsLeft} left';
    case Flip(:final column):
      return 'Card turned: ${lower(_tableau(after)[column].last.spokenName)}';
    case MoveGroup():
      return 'Finished';
  }
}

/// One sentence per applied step: the move, then any card turned, then the
/// runs completed, joined with ". ". The win is the win card's own
/// "Game complete".
String describeStep(Game before, Move move, Game after) {
  final parts = [describeMove(before, move, after)];
  if (move is! Flip) {
    final downBefore = {
      for (final column in _tableau(before))
        for (final c in column)
          if (!c.faceUp && c.id >= 0) c.id,
    };
    final turned = [
      for (final column in _tableau(after))
        for (final c in column)
          if (c.faceUp && downBefore.contains(c.id)) c,
    ];
    for (final c in turned) {
      parts.add('Card turned: ${lower(c.spokenName)}');
    }
  }
  if (before is SpiderGame && after is SpiderGame) {
    final done = after.completed.sublist(before.completed.length);
    if (done.length == 1) {
      parts.add('Run completed, ${done.single.name}');
    } else if (done.length > 1) {
      final names = done.map((s) => s.name).toList();
      final last = names.removeLast();
      parts.add('Runs completed, ${names.join(', ')} and $last');
    }
  }
  return parts.join('. ');
}

/// What a refusal says: a deal that cannot happen, an empty stock, or the
/// plain "Can't move there".
String describeRefusal(Game game, Move? move) {
  switch (move) {
    case DealRow():
      final s = game as SpiderGame;
      return s.rowsLeft == 0
          ? 'No deals left'
          : "Can't deal: fill every column";
    case Draw():
    case Recycle():
      return 'Stock empty';
    default:
      return "Can't move there";
  }
}

/// The hint spoken (the ring is visual only); null for no moves, which the
/// banner announces.
String? describeHint(Game game, engine.Hint hint) {
  switch (hint) {
    case engine.NoMovesLeft():
      return null;
    case engine.MoveHint(:final move):
      switch (move) {
        case Draw():
          return 'Hint: draw a card';
        case Recycle():
          return 'Hint: recycle the stock';
        case DealRow():
          return 'Hint: deal a row';
        case Flip(:final column):
          return 'Hint: turn over ${columnName(column)}';
        default:
          return 'Hint: ${lower(describeMove(game, move, game))}';
      }
  }
}

/// A custom action: its spoken label and the move it applies.
class CardAction {
  const CardAction(this.label, this.move);

  final String label;
  final Move move;

  @override
  String toString() => 'CardAction($label)';
}

/// The actions the card at [index] of [pile] offers: every legal
/// destination from the engine (pointless ones included), foundation first
/// then columns ascending, plus "Turn over" for a face-down top with
/// auto-flip off.
List<CardAction> actionsFor(Game game, BoardPile pile, int index) {
  final moves = game.legalMoves();
  final out = <(int, int, CardAction)>[];
  void toColumn(int to, Move m) {
    final empty = _tableau(game)[to].isEmpty;
    out.add((
      1,
      to,
      CardAction('Move to ${columnName(to)}${empty ? ', empty' : ''}', m),
    ));
  }

  void foundation(Suit suit, Move m) => out.add((
    0,
    suit.index,
    CardAction('Move to ${foundationName(suit)}', m),
  ));

  for (final m in moves) {
    switch ((pile, m)) {
      case (
            TableauPile(:final column),
            MoveRun(:final from, :final start, :final to),
          )
          when from == column && start == index:
        toColumn(to, m);
      case (
            TableauPile(:final column),
            MoveCards(:final from, :final start, :final to),
          )
          when from == column && start == index:
        toColumn(to, m);
      case (TableauPile(:final column), TableauToFoundation(:final from))
          when from == column && index == _tableau(game)[column].length - 1:
        foundation(_tableau(game)[column].last.suit, m);
      case (TableauPile(:final column), Flip(column: final c))
          when c == column && index == _tableau(game)[column].length - 1:
        out.add((2, 0, CardAction('Turn over', m)));
      case (WastePile(), WasteToTableau(:final to)):
        toColumn(to, m);
      case (WastePile(), WasteToFoundation()):
        foundation((game as KlondikeGame).waste.last.suit, m);
      case (
            FoundationPile(:final suit),
            FoundationToTableau(:final foundation, :final to),
          )
          when foundation == suit.index:
        toColumn(to, m);
      default:
        break;
    }
  }
  out.sort(
    (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
  );
  return [for (final e in out) e.$3];
}

/// The stock's actions: "Draw" / "Recycle" (Klondike), "Deal a row" (Spider).
List<CardAction> stockActions(Game game) => [
  for (final m in game.legalMoves())
    switch (m) {
      Draw() => const CardAction('Draw', Draw()),
      Recycle() => const CardAction('Recycle', Recycle()),
      DealRow() => const CardAction('Deal a row', DealRow()),
      _ => null,
    },
].nonNulls.toList();

/// The pile a move takes its cards from, for the refusal's shake.
(BoardPile, int?)? sourceOf(Move move) => switch (move) {
  MoveRun(:final from, :final start) => (TableauPile(from), start),
  MoveCards(:final from, :final start) => (TableauPile(from), start),
  TableauToFoundation(:final from) => (TableauPile(from), null),
  WasteToTableau() || WasteToFoundation() => (const WastePile(), null),
  FoundationToTableau(:final foundation) => (
    FoundationPile(Suit.values[foundation]),
    null,
  ),
  Draw() || Recycle() || DealRow() => (const StockPile(), null),
  Flip() || MoveGroup() => null,
};

List<List<Card>> _tableau(Game game) => switch (game) {
  KlondikeGame k => k.tableau,
  SpiderGame s => s.tableau,
};
