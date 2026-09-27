import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/settings_store.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/feedback/clips.dart';
import 'package:honest_solitaire/feedback/game_feedback.dart';
import 'package:honest_solitaire/feedback/music_controller.dart';
import 'package:honest_solitaire/feedback/sound_player.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import '../ui/win_fixtures.dart';

import 'package:honest_solitaire/ui/board/card_motion.dart';

/// A bridge that records calls and answers as told.
class FakePlayer implements SoundPlayer {
  final List<String> calls = [];
  bool musicActiveElsewhere = false;

  @override
  Future<void> load(Map<Clip, ClipSpec> clips) async => calls.add('load');
  @override
  void play(Clip clip) => calls.add('play:${clip.name}');
  @override
  Future<bool> startMusic() async {
    calls.add('musicStart');
    return !musicActiveElsewhere;
  }

  @override
  Future<void> pauseMusic() async => calls.add('musicPause');
  @override
  Future<void> stopMusic() async => calls.add('musicStop');
  @override
  Future<void> dispose() async => calls.add('release');
}

GameController controllerFor(Game game, {bool sound = true}) => GameController(
  game,
  ValueNotifier(PlaySettings(oneTap: false, sound: sound)),
  ValueNotifier(const DisplayOptions()),
  dealNumberSource: () => DealNumber(77),
  observeLifecycle: false,
);

FeedbackStep step(Set<FeedbackEvent> e, {bool sweep = false}) =>
    FeedbackStep(e, sweep: sweep);

void main() {
  group('clipFor', () {
    test('one clip by priority: chime > deal > flip > snap; silent steps play none', () {
      expect(
        clipFor(step({FeedbackEvent.win, FeedbackEvent.snap})),
        Clip.chime,
      );
      expect(
        clipFor(
          step({
            FeedbackEvent.runCompleted,
            FeedbackEvent.dealRow,
            FeedbackEvent.flip,
          }),
        ),
        Clip.chime,
      );
      expect(
        clipFor(step({FeedbackEvent.foundationCompleted, FeedbackEvent.snap})),
        Clip.chime,
      );
      expect(
        clipFor(
          step({
            FeedbackEvent.foundationCompleted,
            FeedbackEvent.snap,
          }, sweep: true),
        ),
        Clip.snap,
        reason: 'Kings inside the sweep do not chime',
      );
      expect(
        clipFor(step({FeedbackEvent.win, FeedbackEvent.snap}, sweep: true)),
        Clip.chime,
        reason: 'the win chimes',
      );
      expect(clipFor(step({FeedbackEvent.newDeal})), Clip.deal);
      expect(
        clipFor(step({FeedbackEvent.dealRow, FeedbackEvent.flip})),
        Clip.deal,
      );
      expect(
        clipFor(step({FeedbackEvent.flip, FeedbackEvent.snap})),
        Clip.flip,
      );
      expect(clipFor(step({FeedbackEvent.snap})), Clip.snap);
      for (final silent in [FeedbackEvent.refused, FeedbackEvent.peek]) {
        expect(clipFor(step({silent})), isNull, reason: silent.name);
      }
      expect(clipFor(step(const {})), isNull);
      // Every combination resolves to at most one clip.
      final all = FeedbackEvent.values;
      for (var mask = 1; mask < 1 << all.length; mask++) {
        final events = {
          for (var i = 0; i < all.length; i++)
            if (mask & (1 << i) != 0) all[i],
        };
        final clip = clipFor(step(events));
        final expected =
            events.contains(FeedbackEvent.win) ||
                events.contains(FeedbackEvent.runCompleted) ||
                events.contains(FeedbackEvent.foundationCompleted)
            ? Clip.chime
            : events.contains(FeedbackEvent.newDeal) ||
                  events.contains(FeedbackEvent.dealRow)
            ? Clip.deal
            : events.contains(FeedbackEvent.flip)
            ? Clip.flip
            : events.contains(FeedbackEvent.snap)
            ? Clip.snap
            : null;
        expect(clip, expected, reason: '$events');
      }
    });
  });

  group('the controller\'s steps', () {
    test('a draw snaps, a revealing move flips, a King chimes, a refusal and undo are as told', () {
      final controller = controllerFor(
        klondike(
          tableau: [cards('5C* QD'), cards('KC'), [], [], [], [], []],
          stock: cards('2S* 3S*'),
          foundations: [
            suitRun(Suit.spades, 0),
            suitRun(Suit.hearts, 12),
            [],
            [],
          ],
          waste: cards('KH'),
        ),
      );
      final steps = <FeedbackStep>[];
      controller.feedback.addListener(
        () => steps.add(controller.feedback.value!),
      );
      controller.move(const WastePile(), 0, const FoundationPile(Suit.hearts));
      expect(steps.last.events, contains(FeedbackEvent.foundationCompleted));
      controller.tapPile(const StockPile(), null);
      expect(steps.last.events, {
        FeedbackEvent.snap,
      }, reason: 'a draw is a snap even though the card turns up');
      controller.move(const TableauPile(0), 1, const TableauPile(1));
      expect(steps.last.events, {
        FeedbackEvent.flip,
        FeedbackEvent.snap,
      }, reason: 'the 5C turned up');
      controller.undo();
      expect(steps.last.events, {
        FeedbackEvent.snap,
      }, reason: 'undo snaps, never flips or chimes');
      controller.tapPile(const TableauPile(1), 0);
      controller.tapPile(
        const FoundationPile(Suit.clubs),
        null,
        at: const Duration(milliseconds: 500),
      );
      expect(steps.last.events, {FeedbackEvent.refused});
      controller.restart();
      expect(steps.last.events, {FeedbackEvent.newDeal});
      controller.dispose();
    });

    test('a Spider row deals; a completed run chimes; the sweep snaps per step and chimes once at the win', () {
      final spiderGame = spider(
        tableau: [
          [c('5H*'), ...kingDown(Suit.spades, 2)],
          cards('AS'),
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
        ],
        stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
        options: const SpiderOptions(suits: SpiderSuits.two, relaxed: true),
      );
      final controller = controllerFor(spiderGame);
      final steps = <FeedbackStep>[];
      controller.feedback.addListener(
        () => steps.add(controller.feedback.value!),
      );
      controller.move(const TableauPile(1), 0, const TableauPile(0));
      expect(
        steps.last.events,
        containsAll([FeedbackEvent.runCompleted, FeedbackEvent.flip]),
      );
      controller.dealRow();
      expect(steps.last.events, {FeedbackEvent.dealRow});
      controller.dispose();

      final sweep = controllerFor(oneMoveFromSolved);
      final sweepSteps = <FeedbackStep>[];
      sweep.feedback.addListener(() => sweepSteps.add(sweep.feedback.value!));
      // Without animations the sweep shows its last step at once (#99).
      sweep.motion = AppMotion.none;
      sweep.move(const WastePile(), 0, const FoundationPile(Suit.clubs));
      expect(sweep.game.isWon, isTrue);
      expect(sweep.finishing, isFalse);
      final inSweep = sweepSteps.where((s) => s.sweep).toList();
      expect(inSweep, isNotEmpty);
      expect(inSweep.last.events, contains(FeedbackEvent.win));
      expect(clipFor(inSweep.last), Clip.chime, reason: 'the win chimes once');
      for (final s in inSweep.sublist(0, inSweep.length - 1)) {
        expect(
          clipFor(s),
          Clip.snap,
          reason: 'a step snaps, its King does not chime',
        );
      }
      sweep.dispose();
    });
  });

  group('GameFeedback', () {
    test('plays the step\'s clip when Sound effects is on; nothing at all when off', () {
      for (final on in [true, false]) {
        final controller = controllerFor(
          KlondikeGame.deal(DealNumber(3)),
          sound: on,
        );
        final player = FakePlayer();
        final feedback = GameFeedback(
          controller,
          controller.playSettings,
          player,
        );
        controller.tapPile(const StockPile(), null);
        controller.restart();
        controller.tapPile(const TableauPile(0), 0);
        controller.tapPile(
          const FoundationPile(Suit.clubs),
          null,
          at: const Duration(milliseconds: 500),
        );
        if (on) {
          expect(player.calls, [
            'play:snap',
            'play:deal',
          ], reason: 'the refusal is silent');
        } else {
          expect(
            player.calls,
            isEmpty,
            reason: 'zero plays, not just "not the clip"',
          );
        }
        feedback.dispose();
        controller.dispose();
      }
    });

    test('turning Sound effects on plays one snap; the restore at launch plays none', () async {
      final store = AppStore.memory();
      await store.write(StoreDoc.settings, {'sound': true});
      final play = ValueNotifier(const PlaySettings(sound: false));
      final display = ValueNotifier(const DisplayOptions());
      final settings = SettingsStore(
        store,
        play,
        display,
        observeLifecycle: false,
      );
      var snaps = 0;
      var ticks = 0;
      final samples = SettingsSamples(
        play,
        settings,
        onSoundOn: () => snaps++,
        onHapticsOn: () => ticks++,
      );
      await settings.load();
      expect(play.value.sound, isTrue);
      expect(snaps, 0, reason: 'the restore is not the player');
      play.value = play.value.copyWith(sound: false);
      play.value = play.value.copyWith(sound: true);
      expect(snaps, 1);
      play.value = play.value.copyWith(sound: true);
      expect(snaps, 1, reason: 'no change, no sample');
      play.value = play.value.copyWith(haptics: false);
      play.value = play.value.copyWith(haptics: true);
      expect(ticks, 1);
      samples.dispose();
      settings.dispose();
    });
  });

  group('ChannelSoundPlayer', () {
    testWidgets(
      'loads, plays by name, and a bridge error leaves play working',
      (tester) async {
        final calls = <MethodCall>[];
        var failLoad = false;
        const channel = MethodChannel('honestsolitaire/sound');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            if (call.method == 'load' && failLoad) {
              throw PlatformException(code: 'boom');
            }
            if (call.method == 'load') return (call.arguments as Map).length;
            if (call.method == 'play' && call.arguments == 'flip') {
              throw PlatformException(code: 'no-flip');
            }
            if (call.method == 'musicStart') return true;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final logs = <String>[];
        final player = ChannelSoundPlayer(log: logs.add);
        player.play(Clip.snap);
        expect(calls, isEmpty, reason: 'plays before loading are dropped');
        await player.load(clips);
        expect(calls.single.method, 'load');
        expect(
          (calls.single.arguments as Map)['music'],
          'assets/audio/music.wav',
        );
        player.play(Clip.flip);
        player.play(Clip.snap);
        await tester.pump();
        expect(calls.map((c) => c.method).toList(), ['load', 'play', 'play']);
        expect(
          logs.where((l) => l.contains('flip')),
          hasLength(1),
          reason: 'a play error is logged once',
        );
        expect(await player.startMusic(), isTrue);
        await player.pauseMusic();
        await player.stopMusic();
        await player.dispose();
        expect(calls.last.method, 'release');
        // A failed load: silent for the session, logged once, never throws.
        calls.clear();
        failLoad = true;
        final dead = ChannelSoundPlayer(log: logs.add);
        await dead.load(clips);
        dead.play(Clip.snap);
        expect(await dead.startMusic(), isFalse);
        await tester.pump();
        expect(calls.map((c) => c.method).toList(), ['load']);
      },
    );
  });

  group('MusicController', () {
    test('starts only with a board showing, unpaused, foreground and the setting; pauses on each; stops only on a new game', () async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
      final visible = ValueNotifier(false);
      final player = FakePlayer();
      final music = MusicController(
        controller,
        controller.playSettings,
        visible,
        player,
        observeLifecycle: false,
      );
      await music.settle();
      expect(player.calls, isEmpty, reason: 'off by default');
      controller.playSettings.value = const PlaySettings(music: true);
      await music.settle();
      expect(player.calls, isEmpty, reason: 'no board showing');
      visible.value = true;
      await music.settle();
      expect(player.calls, ['musicStart']);
      expect(music.playing, isTrue);
      controller.pause();
      await music.settle();
      expect(player.calls.last, 'musicPause');
      controller.resume();
      await music.settle();
      expect(player.calls.last, 'musicStart');
      visible.value = false;
      await music.settle();
      expect(player.calls.last, 'musicPause');
      visible.value = true;
      await music.settle();
      controller.playSettings.value = const PlaySettings(music: false);
      await music.settle();
      expect(player.calls.last, 'musicPause');
      expect(
        player.calls.where((c) => c == 'musicStop'),
        isEmpty,
        reason: 'off keeps the position',
      );
      controller.playSettings.value = const PlaySettings(music: true);
      await music.settle();
      expect(player.calls.last, 'musicStart');
      controller.replaceGame(SpiderGame.deal(DealNumber(4)));
      await music.settle();
      expect(player.calls.sublist(player.calls.length - 2), [
        'musicStop',
        'musicStart',
      ], reason: 'a new game restarts from the top');
      controller.resumeGame(KlondikeGame.deal(DealNumber(9)), hasMove: true);
      await music.settle();
      expect(
        player.calls.last,
        isNot('musicStop'),
        reason: 'a resume is not a new game',
      );
      music.dispose();
      controller.dispose();
    });

    test('never starts while another app plays audio, and retries at the next change', () async {
      final controller = controllerFor(KlondikeGame.deal(DealNumber(3)));
      final visible = ValueNotifier(true);
      final player = FakePlayer()..musicActiveElsewhere = true;
      final music = MusicController(
        controller,
        controller.playSettings,
        visible,
        player,
        observeLifecycle: false,
      );
      controller.playSettings.value = const PlaySettings(music: true);
      await music.settle();
      expect(player.calls, ['musicStart']);
      expect(music.playing, isFalse, reason: 'the bridge refused');
      player.musicActiveElsewhere = false;
      controller.pause();
      controller.resume();
      await music.settle();
      expect(player.calls.last, 'musicStart');
      expect(music.playing, isTrue);
      music.dispose();
      controller.dispose();
    });
  });
}
