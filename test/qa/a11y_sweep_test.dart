@Tags(['guard'])
library;

// qa/a11y-sweep.md (#116) has the owner win a short deal of each game with
// TalkBack, one written line per move, and stage the other announcements in
// listed steps. This reads the lines back out of the script, finds the legal
// move each one names from the position before it, and plays them through
// the game controller the way TalkBack's double-taps and custom actions
// reach it; the staged steps are played the same way and each phrase they
// produce must be quoted in the script. A line that is not a move, is worded
// differently from what the app will say, or stops short of where the
// script says it ends fails here before the owner plays it.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/finish.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/board/board_semantics.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/motion.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../guards/repo_files.dart';
import 'a11y_lines.dart';

const sweepPath = 'qa/a11y-sweep.md';

typedef Block = ({
  int? deal,
  String? ends,
  String body,
  List<(int, String)> lines,
});

/// One game's block in the script: `<!-- a11y-lines: klondike -->` …
/// `<!-- /a11y-lines -->`, holding `Deal number **N**`, the numbered move
/// lines and `Ends with: …`.
Block block(String script, String game) {
  final open = '<!-- a11y-lines: $game -->';
  final start = script.indexOf(open);
  if (start < 0) return (deal: null, ends: null, body: '', lines: const []);
  final end = script.indexOf('<!-- /a11y-lines -->', start);
  final body = script.substring(start, end < 0 ? script.length : end);
  final deal = RegExp(r'Deal number \*\*(\d+)\*\*').firstMatch(body);
  final ends = RegExp(r'^Ends with: (.+)$', multiLine: true).firstMatch(body);
  return (
    deal: deal == null ? null : int.parse(deal[1]!),
    ends: ends?[1]!.trim(),
    body: body,
    lines: [
      for (final m in RegExp(
        r'^(\d+)\. (.+)$',
        multiLine: true,
      ).allMatches(body))
        (int.parse(m[1]!), m.group(0)!),
    ],
  );
}

/// A controller as the sweep's phone has it: TalkBack on (every tap
/// selects), One-tap on, Auto-flip on, Auto-finish on, sound off, no card
/// motion.
GameController talkBackController(Game deal) {
  final c = GameController(
    deal,
    ValueNotifier(const PlaySettings(sound: false)),
    ValueNotifier(const DisplayOptions()),
    dealNumberSource: () => DealNumber(1),
    observeLifecycle: false,
  );
  c.alwaysSelect = true;
  c.motion = AppMotion.none;
  return c;
}

/// Everything [act] has the controller say.
List<String> hear(GameController c, void Function() act) {
  final said = <String>[];
  void listen() => said.add(c.spoken.value!);
  c.spoken.addListener(listen);
  act();
  c.spoken.removeListener(listen);
  return said;
}

/// Plays [step] as the owner will: the source node, then the destination
/// node, by double-tap; or the source's custom action by its label. A
/// TalkBack double-tap reaches the board as a semantics tap, with no time.
void perform(GameController c, TalkBackStep step) {
  switch (step) {
    case DoubleTapStep(:final target, :final targetIndex):
      c.tapPile(step.source, step.sourceIndex);
      if (target != null) c.tapPile(target, targetIndex);
    case ActionStep(:final action):
      final offered = step.source is StockPile
          ? stockActions(c.game)
          : actionsFor(c.game, step.source, step.sourceIndex!);
      final chosen = offered.where((a) => a.label == action).toList();
      expect(
        chosen,
        hasLength(1),
        reason: 'a11y-sweep: "$action" is not one action on its node',
      );
      c.applyMove(chosen.single.move);
  }
}

/// The cards a double-tap on [step]'s source selects.
List<Card> selectedRun(Game g, TalkBackStep step) {
  final index = step.sourceIndex!;
  return switch ((g, step.source)) {
    (KlondikeGame k, TableauPile(:final column)) => k.tableau[column].sublist(
      index,
    ),
    (SpiderGame s, TableauPile(:final column)) => s.tableau[column].sublist(
      index,
    ),
    (KlondikeGame k, WastePile()) => [k.waste.last],
    (KlondikeGame k, FoundationPile(:final suit)) => [
      k.foundations[suit.index].last,
    ],
    _ => throw StateError('no run at ${step.source}'),
  };
}

/// Replays [b]'s lines on [c] from its deal, with the staged stock taps
/// where the script places them.
void replay(GameController c, Block b, String game) {
  expect(b.lines, isNotEmpty, reason: 'a11y-sweep: $game lists no moves');
  var g = c.game;
  for (final (i, (n, text)) in b.lines.indexed) {
    expect(n, i + 1, reason: 'a11y-sweep: $game lines are not numbered 1..');
    final step = matchLine(g, text, n);
    expect(
      step,
      isNotNull,
      reason:
          'a11y-sweep: $game line $n is not a move from the position before '
          'it, worded as TalkBack says it:\n$text',
    );
    final history = c.game.historyLength;
    final said = hear(c, () => perform(c, step!));
    expect(
      [c.game.historyLength, c.game.historyMoves.lastOrNull],
      [history + 1, step!.move],
      reason: 'a11y-sweep: $game line $n does not make its move on the board',
    );
    final expected = [
      if (step case DoubleTapStep(target: _?))
        '${runWords(selectedRun(g, step))} selected',
      step.said,
    ];
    expect(
      said.take(expected.length).toList(),
      expected,
      reason: 'a11y-sweep: $game line $n is not what the app announces',
    );
    g = (g.apply(step.move) as Applied<Game>).game;
    final staged = stagedTaps(b)[n];
    if (staged != null) {
      final (label, phrase) = staged;
      expect(
        nodeLabel(g, const StockPile(), null),
        label,
        reason: 'a11y-sweep: $game\'s stock after line $n is not "$label"',
      );
      final heard = hear(c, () => c.tapPile(const StockPile(), null));
      expect(
        [
          heard,
          identical(c.game, g) || c.game.historyLength == g.historyLength,
        ],
        [
          [phrase],
          isTrue,
        ],
        reason:
            'a11y-sweep: $game\'s staged tap after line $n is not refused '
            'with "$phrase"',
      );
    }
  }
}

/// The block's staged stock taps: `- After line N … Double-tap "label" —
/// hear "phrase"`, by line number.
Map<int, (String, String)> stagedTaps(Block b) => {
  for (final m in RegExp(
    r'^- After line (\d+)[^\n]*?Double-tap "([^"]+)" — hear "([^"]+)"',
    multiLine: true,
  ).allMatches(b.body))
    int.parse(m[1]!): (m[2]!, m[3]!),
};

/// Every phrase in [said] is quoted in [text].
void quoted(String text, Iterable<String> said, String where) {
  final missing = [
    for (final s in said)
      if (!text.contains('"$s"')) s,
  ];
  expect(
    missing,
    isEmpty,
    reason: 'a11y-sweep: $where does not quote what the app says: $missing',
  );
}

void main() {
  final script = readFile(sweepPath);
  final klondike = block(script, 'klondike');
  final spider = block(script, 'spider');

  KlondikeGame klondikeDeal() {
    expect(
      klondike.deal,
      isNotNull,
      reason: 'a11y-sweep: no klondike block with a deal number',
    );
    return KlondikeGame.deal(DealNumber(klondike.deal!), a11yKlondikeOptions);
  }

  test('the staged Klondike announcements are the ones the app makes', () {
    final deal = klondikeDeal();
    final c = talkBackController(deal);
    final first = matchLine(deal, klondike.lines.first.$2, 1)!;
    final ace = (first.source, first.sourceIndex);
    final column = (ace.$1 as TableauPile).column;
    final said = <String>[
      ...hear(c, c.hint),
      ...hear(c, () {
        c.tapPile(ace.$1, ace.$2);
        c.tapPile(ace.$1, ace.$2! - 1); // the column's face-down node
      }),
      ...hear(c, () {
        c.tapPile(ace.$1, ace.$2);
        // Column 2's face-down node: a place the card cannot go.
        c.tapPile(const TableauPile(1), 0);
      }),
      ...hear(c, () => c.tapPile(const StockPile(), null)),
      ...hear(c, c.undo),
      ...hear(c, () {
        c.tapPile(ace.$1, ace.$2);
        c.tapPile(ace.$1, ace.$2); // the same card again
      }),
    ];
    expect(
      c.game.historyLength,
      0,
      reason: 'a11y-sweep: the staged steps do not leave the deal as dealt',
    );
    expect(said, hasLength(9), reason: 'a11y-sweep: staged steps: $said');
    quoted(klondike.body, [
      ...said,
      nodeLabel(deal, ace.$1, ace.$2),
      faceDownColumnLabel(column, deal.tableau[column].sublist(0, ace.$2)),
      faceDownColumnLabel(1, deal.tableau[1].sublist(0, 1)),
      stockLabel(deal),
    ], 'the Klondike staging');
    c.dispose();
  });

  test('the Klondike lines play by TalkBack to the end the script names', () {
    final c = talkBackController(klondikeDeal());
    replay(c, klondike, 'klondike');
    final g = c.game as KlondikeGame;
    switch (klondike.ends) {
      case 'FINISH':
        expect(
          !g.isWon && canFinish(g) && !isSolved(g),
          isTrue,
          reason:
              'a11y-sweep: klondike does not end with FINISH on offer and '
              'Auto-finish waiting',
        );
        // The recycle staged before FINISH.
        final draws = g.stock.length;
        final said = hear(c, () {
          for (var i = 0; i <= draws; i++) {
            c.tapPile(const StockPile(), null);
          }
        });
        expect(
          said.last,
          'Stock recycled',
          reason: 'a11y-sweep: the staged recycle is not a recycle',
        );
        expect(
          klondike.body,
          contains('"Stock, $draws cards"'),
          reason: 'a11y-sweep: the staged recycle names the wrong stock',
        );
        quoted(klondike.body, [
          'Stock, empty, double-tap to recycle',
          said.last,
        ], 'the Klondike recycle');
        expect(c.canFinish, isTrue, reason: 'a11y-sweep: FINISH gone');
        final finishing = hear(c, c.finish);
        quoted(klondike.body, finishing, 'the Klondike FINISH');
      case 'Auto-finish':
        expect(
          g.isWon,
          isTrue,
          reason: 'a11y-sweep: klondike\'s last line does not auto-finish',
        );
      default:
        fail('a11y-sweep: klondike "Ends with:" is ${klondike.ends}');
    }
    expect(
      c.game.isWon,
      isTrue,
      reason: 'a11y-sweep: klondike does not end in a win',
    );
    c.dispose();
  });

  test('the no-moves, restart and new-deal announcements', () {
    final d3 = KlondikeGame.deal(
      DealNumber(71),
      const KlondikeOptions(
        draw: DrawMode.three,
        scoring: ScoringMode.standard,
        timed: false,
      ),
    );
    final c = talkBackController(klondikeDeal());
    final said = hear(c, () => c.replaceGame(d3, dealAnimation: true));
    c.hint();
    expect(
      c.currentHint?.noMoves,
      isTrue,
      reason: 'a11y-sweep: deal 71 (Draw 3) has moves at the deal',
    );
    said.addAll(hear(c, c.restart));
    quoted(script, [...said, 'No moves left'], 'A09');
    expect(script, contains('deal number **71**'));
    c.dispose();
  });

  test('the Spider lines play by TalkBack to the win', () {
    expect(
      spider.deal,
      isNotNull,
      reason: 'a11y-sweep: no spider block with a deal number',
    );
    final deal = SpiderGame.deal(DealNumber(spider.deal!), a11ySpiderOptions);
    final c = talkBackController(deal);
    replay(c, spider, 'spider');
    expect(spider.ends, 'the win', reason: 'a11y-sweep: spider "Ends with:"');
    expect(
      c.game.isWon,
      isTrue,
      reason: 'a11y-sweep: spider does not end in a win',
    );
    c.dispose();
  });
}
