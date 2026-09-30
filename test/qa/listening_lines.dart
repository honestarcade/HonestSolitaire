// The searches behind qa/listening.md (#115), shared by
// tools/find_listening_deals.dart (which scans deal numbers for the shortest
// lines) and test/qa/listening_test.dart (which replays the chosen deals'
// lines through the game controller and checks the checklist quotes them).
// Pure Dart: the engine and the spoken move names only.
import 'package:honest_solitaire/engine/finish.dart';
import 'package:honest_solitaire/engine/game.dart';

/// The Klondike deal and the one-suit Spider deal the checklist uses: the
/// shortest lines `dart run tools/find_listening_deals.dart` found.
const int listeningKlondikeDeal = 81;
const int listeningSpiderDeal = 3;

/// A short line from [deal] to FINISH being on offer (every tableau card
/// face up), by beam search; null when none within [depth] moves.
List<Move>? toFinish(KlondikeGame deal, {int width = 400, int depth = 120}) =>
    _beam<KlondikeGame>(
      deal,
      width: width,
      depth: depth,
      done: (before, after) => after.allTableauFaceUp && canFinish(after),
      score: _openness,
      key: _klondikeKey,
    );

/// From [game], a short line whose last move puts a King on a foundation
/// by hand, FINISH still on offer after it.
List<Move>? toKing(KlondikeGame game, {int width = 2000, int depth = 80}) =>
    _beam<KlondikeGame>(
      game,
      width: width,
      depth: depth,
      done: (before, after) =>
          _complete(after) > _complete(before) &&
          !after.isWon &&
          canFinish(after),
      score: _fullest,
      key: _klondikeKey,
    );

/// A short line from [deal] to its first completed run.
List<Move>? firstRun(
  SpiderGame deal, {
  int width = 300,
  int depth = 120,
}) => _beam<SpiderGame>(
  deal,
  width: width,
  depth: depth,
  done: (before, after) => after.completed.isNotEmpty,
  score: _runLength,
  key: (g) =>
      '${g.tableau.map((c) => c.map((x) => '${x.rank}${x.faceUp ? 'u' : 'd'}').join()).join('|')}/${g.rowsLeft}',
);

List<Move>? _beam<G extends Game>(
  G start, {
  required int width,
  required int depth,
  required bool Function(G before, G after) done,
  required int Function(G) score,
  required String Function(G) key,
}) {
  var beam = <(G, List<Move>)>[(start, const [])];
  final seen = <String>{key(start)};
  for (var d = 0; d < depth; d++) {
    final next = <(G, List<Move>, int)>[];
    for (final (g, line) in beam) {
      for (final m in g.legalMoves()) {
        final r = g.apply(m);
        if (r is! Applied<Game>) continue;
        final after = r.game as G;
        final moves = [...line, m];
        if (done(g, after)) return moves;
        if (!seen.add(key(after))) continue;
        next.add((after, moves, score(after)));
      }
    }
    if (next.isEmpty) return null;
    next.sort((a, b) => b.$3.compareTo(a.$3));
    beam = [for (final e in next.take(width)) (e.$1, e.$2)];
  }
  return null;
}

int _complete(KlondikeGame g) =>
    g.foundations.where((f) => f.length == 13).length;

String _klondikeKey(KlondikeGame g) => [
  for (final c in g.tableau)
    c.map((x) => '${x.id}${x.faceUp ? 'u' : 'd'}').join(','),
  g.stock.length,
  g.waste.length,
  for (final f in g.foundations) f.length,
].join('|');

/// Face-down cards cost most, the fullest foundation counts next.
int _openness(KlondikeGame g) {
  var down = 0;
  for (final c in g.tableau) {
    down += c.where((x) => !x.faceUp).length;
  }
  final lengths = [for (final f in g.foundations) f.length]..sort();
  return -down * 40 + lengths.last * 30 + lengths.fold(0, (a, b) => a + b) * 4;
}

/// Foundation lengths squared: one suit climbing beats four creeping.
int _fullest(KlondikeGame g) =>
    g.foundations.fold(0, (a, f) => a + f.length * f.length);

/// The longest in-sequence run on top of a column counts most, then
/// face-up cards, then rows kept in hand.
int _runLength(SpiderGame g) {
  var best = 0;
  var up = 0;
  for (final column in g.tableau) {
    var run = column.isEmpty ? 0 : 1;
    for (var i = column.length - 1; i > 0; i--) {
      final a = column[i - 1], b = column[i];
      if (!a.faceUp || !b.faceUp || a.rank != b.rank + 1 || a.suit != b.suit) {
        break;
      }
      run++;
    }
    if (run > best) best = run;
    up += column.where((c) => c.faceUp).length;
  }
  return best * 100 + up * 3 + g.rowsLeft * 5;
}
