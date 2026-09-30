// Scans deal numbers for qa/a11y-sweep.md's two short TalkBack wins (#116):
// the Klondike deal (Draw 1, Standard, Untimed, typed number) with the
// fewest manual moves before FINISH is on offer, by the solver's line at its
// default budget; and the one-suit strict Spider deal with the fewest
// winning moves the #112 beam search finds. Then prints both deals' lines as
// the script words them. The searches and the wording live in
// test/qa/a11y_lines.dart; test/qa/a11y_sweep_test.dart reads the lines
// back out of the script and replays them.
//
//   dart run tools/find_a11y_deals.dart [--klondike-to N] [--spider-to N]
//       [--workers N]
//   dart run tools/find_a11y_deals.dart --klondike N --spider N
//
// A deal named with --klondike or --spider is not scanned for; its lines
// are printed as they are.
import 'dart:io';
import 'dart:isolate';

import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/finish.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../test/qa/a11y_lines.dart';

/// The line length for deal [n], searching no deeper than [cap] moves
/// where the search has a depth (the Spider beam); null when none is found.
typedef _Scan = int? Function(int n, int? cap);

int? _klondike(int n, int? cap) =>
    klondikeToFinish(KlondikeGame.deal(DealNumber(n), a11yKlondikeOptions))
        ?.length;

int? _spider(int n, int? cap) => spiderToWin(
  SpiderGame.deal(DealNumber(n), a11ySpiderOptions),
  depth: cap ?? 400,
)?.length;

/// Scans 1..[last], [workers] deals at a time, each deal searching no
/// deeper than the shortest line found so far; the shortest line, lowest
/// deal number on a tie.
Future<(int, int)?> _scan(
  String name,
  int last,
  int workers,
  _Scan scan,
) async {
  final found = <(int, int)>[];
  int? best;
  var next = 1;
  var done = 0;
  final watch = Stopwatch()..start();
  Future<void> worker() async {
    while (next <= last) {
      final n = next++;
      final cap = best;
      final length = await Isolate.run(() => scan(n, cap));
      done++;
      if (length != null) {
        found.add((n, length));
        if (best == null || length < best!) {
          best = length;
          stdout.writeln(
            '$name $n: $length moves '
            '($done scanned, ${watch.elapsed.inSeconds} s)',
          );
        }
      }
    }
  }

  await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  found.sort((x, y) => x.$2 != y.$2 ? x.$2.compareTo(y.$2) : x.$1 - y.$1);
  stdout.writeln(
    '$name: scanned 1..$last in ${watch.elapsed.inSeconds} s; shortest: '
    '${found.take(3).map((r) => '${r.$1} (${r.$2})').join(', ')}',
  );
  return found.isEmpty ? null : found.first;
}

void _print(String title, Game deal, List<Move> line) {
  stdout.writeln('\n$title — ${line.length} moves');
  for (final (i, step) in talkBackSteps(deal, line).indexed) {
    stdout.writeln(step.line(i + 1));
  }
}

Future<void> main(List<String> args) async {
  int opt(String name, int fallback) {
    final i = args.indexOf(name);
    return i < 0 ? fallback : int.parse(args[i + 1]);
  }

  var k = opt('--klondike', 0);
  var s = opt('--spider', 0);
  final workers = opt('--workers', Platform.numberOfProcessors ~/ 2);
  if (k == 0) {
    final best = await _scan(
      'klondike',
      opt('--klondike-to', 5000),
      workers,
      _klondike,
    );
    if (best != null) k = best.$1;
  }
  if (s == 0) {
    final best = await _scan(
      'spider',
      opt('--spider-to', 5000),
      workers,
      _spider,
    );
    if (best != null) s = best.$1;
  }

  final kDeal = KlondikeGame.deal(DealNumber(k), a11yKlondikeOptions);
  final kLine = klondikeToFinish(kDeal)!;
  var end = kDeal;
  for (final m in kLine) {
    end = (end.apply(m) as Applied<KlondikeGame>).game;
  }
  _print('Klondike deal $k', kDeal, kLine);
  stdout.writeln(
    isSolved(end)
        ? 'stock and waste empty: Auto-finish starts by itself'
        : 'stock or waste left: FINISH is offered, Auto-finish waits',
  );
  final sDeal = SpiderGame.deal(DealNumber(s), a11ySpiderOptions);
  _print('Spider deal $s', sDeal, spiderToWin(sDeal)!);
}
