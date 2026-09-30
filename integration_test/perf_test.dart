// On-device measurement (#117), run by tools/perf.sh through flutter drive
// in profile mode, never by the gate or tools/e2e.sh. Two parts: the engine
// deals every golden deal number exactly as the host pinned it (invariant
// 3), then the winnable search is timed for each Klondike draw mode. The test
// reports; the story enforces the 95 % target from the numbers.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/solver.dart';
import 'package:integration_test/integration_test.dart';

import '../test/guards/engine_golden.dart';
import 'golden_deals.g.dart';

/// Searches per draw mode; tools/perf.sh can lower it for a quick look.
const int searches = int.fromEnvironment('PERF_SEARCHES', defaultValue: 100);

const Duration missAfter = Duration(seconds: 60);

/// One timed search from [base]: milliseconds from `search()` (isolate spawn
/// included) to the verdict, deals tried, and whether `Found` beat the soft
/// limit.
Future<Map<String, Object?>> timeSearch(int base, DrawMode draw) async {
  final watch = Stopwatch()..start();
  final handle = WinnableDealer.search(
    DealNumber(base),
    KlondikeOptions(draw: draw),
  );
  var softHit = false;
  final done = Completer<Map<String, Object?>>();
  Map<String, Object?> row(String verdict, {int? found}) => {
    'draw': draw == DrawMode.one ? 1 : 3,
    'base': base,
    'found': found,
    'ms': watch.elapsedMilliseconds,
    'dealsTried': found == null
        ? null
        : (found - base + DealNumber.max) % DealNumber.max + 1,
    'verdict': verdict,
  };
  final sub = handle.events.listen(
    (e) {
      if (done.isCompleted) return;
      switch (e) {
        case SoftLimitReached():
          softHit = true;
        case Found(:final game):
          done.complete(
            row(softHit ? 'late' : 'within', found: game.dealNumber.value),
          );
        case NotFound():
          done.complete(row('notFound'));
        case Cancelled():
          done.complete(row('cancelled'));
        case Progress():
          break;
      }
    },
    onError: (Object e) {
      if (!done.isCompleted) done.complete(row('error: $e'));
    },
  );
  final result = await done.future.timeout(
    missAfter,
    onTimeout: () => row('timeout'),
  );
  await handle.cancel();
  await sub.cancel();
  return result;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final report = <String, Object?>{};
  binding.reportData = report;

  testWidgets('every golden deal is dealt as the host pinned it', (_) async {
    final mismatches = <String>[];
    var checked = 0;
    for (final MapEntry(key: mode, value: deals) in goldenDealPiles.entries) {
      for (final MapEntry(key: deal, value: piles) in deals.entries) {
        checked++;
        final now = projection(dealFor(mode, deal));
        if (jsonEncode(now) != piles) {
          final pinned = jsonDecode(piles) as Map<String, Object?>;
          final pile = [
            for (final k in pinned.keys)
              if (jsonEncode(pinned[k]) != jsonEncode(now[k])) k,
          ].firstOrNull;
          mismatches.add('$mode deal $deal (first differing pile: $pile)');
        }
      }
    }
    report['golden'] = {'checked': checked, 'mismatches': mismatches};
    expect(
      mismatches,
      isEmpty,
      reason: 'perf: ${mismatches.length} of $checked golden deals differ',
    );
  });

  testWidgets('winnable search timing', (_) async {
    final rows = <Map<String, Object?>>[];
    for (final draw in [DrawMode.one, DrawMode.three]) {
      await timeSearch(1, draw); // warm-up, discarded
      for (var i = 0; i < searches; i++) {
        rows.add(await timeSearch(1000 + 997 * i, draw));
      }
    }
    report['searches'] = rows;
    report['searchesPerDraw'] = searches;
    report['nodeBudget'] = defaultNodeBudget;
  }, timeout: const Timeout(Duration(hours: 4)));
}
