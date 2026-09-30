// Scans deal numbers for qa/listening.md's deals (#115): the Klondike draw-1
// deal, proven winnable by the solver, with the shortest line to FINISH
// being on offer; and the one-suit Spider deal with the shortest line to a
// completed run. The searches live in test/qa/listening_lines.dart, whose
// constants name the deals chosen; test/qa/listening_test.dart replays them.
//
//   dart run tools/find_listening_deals.dart [--klondike-to N] [--spider-to N]
import 'dart:io';

import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/solver.dart';

import '../test/qa/listening_lines.dart';

void main(List<String> args) {
  int opt(String name, int fallback) {
    final i = args.indexOf(name);
    return i < 0 ? fallback : int.parse(args[i + 1]);
  }

  (int, int)? bestK;
  for (var n = 1; n <= opt('--klondike-to', 400); n++) {
    final deal = KlondikeGame.deal(DealNumber(n));
    if (solve(deal) is! Solved) continue;
    final line = toFinish(deal, depth: bestK?.$2 ?? 120);
    if (line == null || (bestK != null && line.length >= bestK.$2)) continue;
    bestK = (n, line.length);
    stdout.writeln('klondike $n: ${line.length} moves to FINISH');
  }

  (int, int)? bestS;
  for (var n = 1; n <= opt('--spider-to', 200); n++) {
    final line = firstRun(
      SpiderGame.deal(DealNumber(n)),
      depth: bestS?.$2 ?? 120,
    );
    if (line == null || (bestS != null && line.length >= bestS.$2)) continue;
    bestS = (n, line.length);
    stdout.writeln('spider $n: ${line.length} moves to a run');
  }
}
