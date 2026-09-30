// The Deals section of qa/test-plan.md names fixed deal numbers and the
// states they reach, so the owner can reach a state on the phone by typing
// a number. This replays every row with the engine: a row whose state the
// engine no longer reaches fails here before anyone plays it by hand.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/hints.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/engine/solver.dart';
import 'package:honest_solitaire/ui/format.dart';

class PlanDeal {
  PlanDeal(this.id, this.game, this.options, this.number, this.states);

  final String id;
  final String game;
  final String options;
  final int number;
  final List<String> states;
}

/// The rows of the `## Deals` table: `| D1 | Klondike | Draw 1 | 48213 | … |`.
List<PlanDeal> dealRows(String plan) {
  final lines = plan.split('\n');
  final start = lines.indexWhere((l) => l.trim() == '## Deals');
  if (start < 0) throw StateError('qa/test-plan.md has no "## Deals" section');
  final rows = <PlanDeal>[];
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) break;
    final m = RegExp(
      r'^\|\s*(D\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*$',
    ).firstMatch(line);
    if (m == null) continue;
    rows.add(
      PlanDeal(
        m[1]!,
        m[2]!,
        m[3]!,
        int.parse(m[4]!),
        m[5]!
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      ),
    );
  }
  return rows;
}

Game dealFor(PlanDeal row) {
  final number = DealNumber(row.number);
  final tokens = row.options.split(',').map((s) => s.trim()).toList();
  switch (row.game) {
    case 'Klondike':
      var draw = DrawMode.one;
      var scoring = ScoringMode.standard;
      for (final t in tokens) {
        switch (t) {
          case 'Draw 1':
            draw = DrawMode.one;
          case 'Draw 3':
            draw = DrawMode.three;
          case 'Standard':
            scoring = ScoringMode.standard;
          case 'Vegas':
            scoring = ScoringMode.vegas;
          case 'None':
            scoring = ScoringMode.none;
          default:
            throw FormatException('${row.id}: unknown Klondike option "$t"');
        }
      }
      return KlondikeGame.deal(
        number,
        KlondikeOptions(draw: draw, scoring: scoring),
      );
    case 'Spider':
      final suits = switch (tokens) {
        ['One suit'] => SpiderSuits.one,
        ['Two suits'] => SpiderSuits.two,
        ['Four suits'] => SpiderSuits.four,
        _ => throw FormatException(
          '${row.id}: Spider options must be one suit count, not "${row.options}"',
        ),
      };
      return SpiderGame.deal(number, SpiderOptions(suits: suits));
    default:
      throw FormatException('${row.id}: unknown game "${row.game}"');
  }
}

/// A card as the plan writes it: `7♦`, `10♠`.
String named(Card card) => '${card.rankName}${card.suit.symbol}';

List<List<Card>> tableauOf(Game game) => switch (game) {
  KlondikeGame k => k.tableau,
  SpiderGame s => s.tableau,
};

/// The first hint in the plan's words.
String hintText(Game game) {
  final tableau = tableauOf(game);
  return switch (hint(game)) {
    NoMovesLeft() => 'no moves left',
    MoveHint(move: MoveRun(:final from, :final start, :final to)) ||
    MoveHint(
      move: MoveCards(:final from, :final start, :final to),
    ) => '${named(tableau[from][start])} onto ${named(tableau[to].last)}',
    MoveHint(move: TableauToFoundation(:final from)) =>
      '${named(tableau[from].last)} to foundation',
    MoveHint(move: Draw() || DealRow()) => 'stock',
    MoveHint(:final move) => 'unnamed move $move',
  };
}

/// What the engine says for one `<kind>: <value>` state of [game].
String actual(String kind, Game game) {
  switch (kind) {
    case 'tops':
      return tableauOf(game).map((c) => named(c.last)).join(' ');
    case 'first draw':
      final k = game as KlondikeGame;
      final drawn = k.apply(const Draw());
      if (drawn is! Applied<KlondikeGame>) return 'refused';
      return drawn.game.waste.map(named).join(' ');
    case 'first hint':
      return hintText(game);
    case 'score at deal':
      return formatScore(game) ?? 'no score';
    case 'solver':
      return switch (solve(game as KlondikeGame)) {
        Solved() => 'winnable',
        Unsolvable() => 'unsolvable',
        Unknown() => 'unknown',
      };
    default:
      throw FormatException('unknown state "$kind"');
  }
}

void main() {
  final plan = File('qa/test-plan.md').readAsStringSync();
  final rows = dealRows(plan);

  test('the Deals section lists deals with unique ids', () {
    expect(rows, isNotEmpty, reason: 'deals: no rows parsed from ## Deals');
    final ids = rows.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'deals: duplicate id');
  });

  for (final row in rows) {
    test('${row.id}: ${row.game} ${row.options} #${row.number} reaches '
        'the states the plan names', () {
      final game = dealFor(row);
      expect(row.states, isNotEmpty, reason: '${row.id} names no state');
      for (final state in row.states) {
        final colon = state.indexOf(':');
        expect(colon, greaterThan(0), reason: '${row.id}: "$state"');
        final kind = state.substring(0, colon).trim();
        final expected = state.substring(colon + 1).trim();
        expect(
          actual(kind, game),
          expected,
          reason: 'deals: ${row.id} "$kind" is not what the engine deals',
        );
      }
    });
  }
}
