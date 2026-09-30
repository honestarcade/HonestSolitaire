// A test-only Spider search for the end-to-end suite (#112). The engine has
// no Spider solver, and following hints loops; a beam search that keeps the
// most promising positions at each depth finds short winning lines.
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

String _key(SpiderGame g) =>
    '${g.tableau.map((c) => c.map((x) => '${x.rank}${x.faceUp ? 'u' : 'd'}').join(',')).join('|')}#${g.rowsLeft}';

/// Higher is closer to a win: completed runs, then face-up cards, empty
/// columns and long ordered runs, with undealt rows as a mild debt.
int _value(SpiderGame g) {
  var v = 2000 * g.completed.length;
  for (final c in g.tableau) {
    if (c.isEmpty) {
      v += 120;
      continue;
    }
    v -= 90 * c.where((x) => !x.faceUp).length;
    var run = 1;
    for (var i = c.length - 1; i > 0; i--) {
      if (c[i - 1].faceUp && c[i - 1].rank == c[i].rank + 1) {
        run++;
      } else {
        break;
      }
    }
    v += 12 * run * run;
  }
  return v - 30 * g.rowsLeft;
}

/// The moves that win [root], or null if the beam finds none.
List<Move>? beamSearch(SpiderGame root, {int width = 150, int depth = 400}) {
  var layer = <(SpiderGame, List<Move>)>[(root, const [])];
  final seen = <String>{_key(root)};
  for (var d = 0; d < depth; d++) {
    final next = <(int, SpiderGame, List<Move>)>[];
    for (final (g, path) in layer) {
      for (final m in g.legalMoves()) {
        if (g.apply(m) case Applied(game: final SpiderGame s)) {
          final p = [...path, m];
          if (s.isWon) return p;
          if (seen.add(_key(s))) next.add((_value(s), s, p));
        }
      }
    }
    if (next.isEmpty) return null;
    next.sort((a, b) => b.$1.compareTo(a.$1));
    layer = [for (final e in next.take(width)) (e.$2, e.$3)];
  }
  return null;
}

/// The first deal from 1000 the beam wins, with its line.
(DealNumber, List<Move>) winnableSpiderDeal(SpiderOptions options) {
  for (var n = 1000; n < 1030; n++) {
    final deal = DealNumber(n);
    final line = beamSearch(SpiderGame.deal(deal, options));
    if (line != null) return (deal, line);
  }
  throw StateError('e2e: no Spider deal in 1000–1029 won by the beam');
}
