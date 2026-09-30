// qa/listening.md (#115) tells the owner which deal and which moves reach
// each sound. This replays those deals through the game controller with
// the feedback layer attached, checks every trigger the checklist promises
// is really reached, and checks the checklist quotes each move line exactly
// as the replay renders it (the move as TalkBack says it, then the clip).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/feedback/clips.dart';
import 'package:honest_solitaire/feedback/game_feedback.dart';
import 'package:honest_solitaire/feedback/haptics.dart';
import 'package:honest_solitaire/feedback/sound_player.dart';
import 'package:honest_solitaire/ui/board/board_semantics.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/motion.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../guards/repo_files.dart';
import 'listening_lines.dart';

class _Ticks implements HapticsPort {
  int count = 0;
  @override
  Future<void> tick() async => count++;
}

/// A controller showing [first], with sound and haptics on and Auto-finish
/// off, as the checklist asks.
(GameController, GameFeedback, _Ticks) _playing(Game first) {
  final controller = GameController(
    first,
    ValueNotifier(const PlaySettings(autoFinish: false)),
    ValueNotifier(const DisplayOptions()),
    dealNumberSource: () => DealNumber(1),
    observeLifecycle: false,
  );
  final ticks = _Ticks();
  final feedback = GameFeedback(
    controller,
    controller.playSettings,
    const NoSoundPlayer(),
    ticks,
  );
  return (controller, feedback, ticks);
}

/// One replayed move: its checklist line, the clip it played (or null) and
/// whether it ticked.
typedef _Heard = ({String line, Clip? clip, bool ticked});

/// Applies [moves] as TalkBack's move actions would, numbering the lines
/// from [from].
List<_Heard> _replay(
  GameController c,
  GameFeedback f,
  _Ticks t,
  List<Move> moves, {
  int from = 1,
}) {
  final out = <_Heard>[];
  for (final (i, m) in moves.indexed) {
    final before = c.game;
    final played = f.played.length;
    final ticks = t.count;
    c.applyMove(m);
    expect(
      identical(c.game, before),
      isFalse,
      reason: 'move ${from + i} ($m) was refused on replay',
    );
    final clip = f.played.length > played ? f.played.last : null;
    out.add((
      line:
          '${from + i}. ${describeStep(before, m, c.game)} — '
          '${clip?.name ?? 'silent'}',
      clip: clip,
      ticked: t.count > ticks,
    ));
  }
  return out;
}

void _quoted(String checklist, List<_Heard> heard) {
  final missing = [
    for (final h in heard)
      if (!checklist.contains(h.line)) h.line,
  ];
  expect(
    missing,
    isEmpty,
    reason:
        'qa/listening.md does not quote these replayed lines:\n'
        '${heard.map((h) => h.line).join('\n')}',
  );
}

void main() {
  final checklist = readFile('qa/listening.md');

  test('Klondike deal: deal, flip, snap, a King chimes by hand, the FINISH win chimes', () {
    final deal = KlondikeGame.deal(DealNumber(listeningKlondikeDeal));
    final (c, f, t) = _playing(KlondikeGame.deal(DealNumber(1)));
    c.replaceGame(deal, dealAnimation: true);
    expect(f.played, [Clip.deal], reason: 'a new deal plays the deal clip');

    final open = toFinish(deal)!;
    final toFinishLines = _replay(c, f, t, open);
    expect(c.canFinish, isTrue, reason: 'FINISH is on offer after the line');
    expect(toFinishLines.first.clip, Clip.flip);
    expect(toFinishLines.map((h) => h.clip), contains(Clip.snap));
    expect(
      toFinishLines.map((h) => h.clip),
      isNot(contains(Clip.chime)),
      reason: 'no King goes up before the King leg',
    );

    final king = toKing(c.game as KlondikeGame)!;
    final kingLines = _replay(c, f, t, king, from: open.length + 1);
    expect(kingLines.last.clip, Clip.chime, reason: 'the King chimes');
    expect(kingLines.last.ticked, isTrue, reason: 'the King ticks');
    expect(
      kingLines.take(kingLines.length - 1).map((h) => h.clip),
      isNot(contains(Clip.chime)),
    );
    expect(c.canFinish, isTrue, reason: 'FINISH is still on offer');

    final before = f.played.length;
    c.motion = AppMotion.none;
    c.finish();
    expect(c.game.isWon, isTrue);
    final sweep = f.played.sublist(before);
    expect(sweep.last, Clip.chime, reason: 'the win chimes');
    expect(
      sweep.take(sweep.length - 1),
      everyElement(Clip.snap),
      reason: 'the sweep snaps; its Kings do not chime',
    );

    _quoted(checklist, [...toFinishLines, ...kingLines]);
    expect(checklist, contains('Deal **$listeningKlondikeDeal**'));
    c.dispose();
  });

  test('Spider one-suit deal: deal rows play the deal clip; the completed run chimes', () {
    final deal = SpiderGame.deal(DealNumber(listeningSpiderDeal));
    expect(deal.options.suits, SpiderSuits.one);
    final (c, f, t) = _playing(KlondikeGame.deal(DealNumber(1)));
    c.replaceGame(deal, dealAnimation: true);
    expect(f.played, [Clip.deal]);

    final lines = _replay(c, f, t, firstRun(deal)!);
    expect(lines.last.clip, Clip.chime, reason: 'the run chimes');
    expect(lines.last.ticked, isTrue, reason: 'the run ticks');
    expect(lines.map((h) => h.clip), contains(Clip.deal));
    _quoted(checklist, lines);
    expect(checklist, contains('Deal **$listeningSpiderDeal**'));
    c.dispose();
  });

  test(
    'haptics: a refused move and a peek tick; an ordinary move does not',
    () {
      final (c, f, t) = _playing(
        KlondikeGame.deal(DealNumber(listeningKlondikeDeal)),
      );
      final open = toFinish(c.game as KlondikeGame)!;
      _replay(c, f, t, open.take(1).toList());
      expect(t.count, 0, reason: 'an ordinary move is silent to the hand');
      // The first column-top-to-column move the engine does not offer.
      final legal = c.game.legalMoves();
      final refused = [
        for (var to = 0; to < 7; to++)
          for (var from = 0; from < 7; from++)
            if (from != to)
              MoveRun(
                from,
                (c.game as KlondikeGame).tableau[from].length - 1,
                to,
              ),
      ].firstWhere((m) => !legal.contains(m));
      c.applyMove(refused);
      expect(t.count, 1, reason: 'a refused move ticks');
      c.startPeek(6);
      expect(t.count, 2, reason: 'a peek ticks');
      c.dispose();
    },
  );
}
