import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/feedback/game_feedback.dart';
import 'package:honest_solitaire/feedback/haptics.dart';
import 'package:honest_solitaire/feedback/sound_player.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/game/finish_sweep.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import '../engine/positions.dart';
import '../ui/win_fixtures.dart';

class RecordingHaptics implements HapticsPort {
  int ticks = 0;
  @override
  Future<void> tick() async => ticks++;
}

/// A controller with feedback attached; [ticks] counts the port's calls.
(GameController, GameFeedback, RecordingHaptics) playing(
  Game game, {
  bool haptics = true,
  bool oneTap = false,
  bool autoFinish = true,
}) {
  final controller = GameController(
    game,
    ValueNotifier(
      PlaySettings(oneTap: oneTap, haptics: haptics, autoFinish: autoFinish),
    ),
    ValueNotifier(const DisplayOptions()),
    dealNumberSource: () => DealNumber(77),
    observeLifecycle: false,
  );
  final port = RecordingHaptics();
  final feedback = GameFeedback(
    controller,
    controller.playSettings,
    const NoSoundPlayer(),
    port,
  );
  return (controller, feedback, port);
}

/// Column 1's Ace completes column 0's K..2 run.
final oneFromRun = spider(
  tableau: [
    kingDown(Suit.spades, 2),
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
);

/// Column 0's King completes the spades foundation.
final oneFromFoundation = klondike(
  tableau: [cards('KS'), cards('KH'), [], [], [], [], []],
  foundations: [suitRun(Suit.spades, 12), [], [], []],
);

/// Two Kings, an empty stock and waste: nothing legal anywhere.
final stuck = klondike(tableau: [cards('KS'), cards('KH'), [], [], [], [], []]);

/// Spider with a stock row but an empty column: the deal is refused.
final dealRefused = spider(
  tableau: [cards('KS'), [], [], [], [], [], [], [], [], []],
  stock: [cards('AS 2S 3S 4S 5S 6S 7S 8S 9S 10S')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterHaptics', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('tick is one light impact on the platform channel', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      await FlutterHaptics(log: (_) {}).tick();
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('HapticFeedback.vibrate', 'HapticFeedbackType.lightImpact'),
      ]);
    });

    test('a platform that refuses is logged once and never throws', () async {
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        throw PlatformException(code: 'no-vibrator');
      });
      final logged = <String>[];
      final h = FlutterHaptics(log: logged.add);
      await h.tick();
      await h.tick();
      expect(logged, hasLength(1));
    });

    test('no platform at all is quiet too', () async {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      final logged = <String>[];
      await FlutterHaptics(log: logged.add).tick();
      expect(logged, hasLength(lessThanOrEqualTo(1)));
    });
  });

  group('tickFor', () {
    test('refusals, runs, foundations and peeks tick; the rest do not', () {
      expect(tickFor(const FeedbackStep({FeedbackEvent.refused})), isTrue);
      expect(tickFor(const FeedbackStep({FeedbackEvent.runCompleted})), isTrue);
      expect(
        tickFor(const FeedbackStep({FeedbackEvent.foundationCompleted})),
        isTrue,
      );
      expect(tickFor(const FeedbackStep({FeedbackEvent.peek})), isTrue);
      for (final e in [
        FeedbackEvent.snap,
        FeedbackEvent.flip,
        FeedbackEvent.newDeal,
        FeedbackEvent.dealRow,
        FeedbackEvent.win,
      ]) {
        expect(tickFor(FeedbackStep({e})), isFalse, reason: e.name);
      }
      // A sweep step ticks only when it completes a foundation.
      expect(
        tickFor(const FeedbackStep({FeedbackEvent.snap}, sweep: true)),
        isFalse,
      );
      expect(
        tickFor(
          const FeedbackStep({
            FeedbackEvent.snap,
            FeedbackEvent.foundationCompleted,
          }, sweep: true),
        ),
        isTrue,
      );
    });
  });

  group('one tick per event', () {
    test('an illegal move: one tick; an ordinary move: none', () {
      final (c, _, t) = playing(oneMoveFromSolved, autoFinish: false);
      c.move(const TableauPile(0), 3, const TableauPile(1)); // 10D on 8C: no
      expect(t.ticks, 1);
      c.move(const WastePile(), 0, const FoundationPile(Suit.clubs)); // AC up
      expect(c.game.moves, 1, reason: 'the ordinary move applied');
      expect(t.ticks, 1);
      c.dispose();
    });

    test('a drop onto a refusing pile through move(): one tick', () {
      final (c, _, t) = playing(stuck);
      c.move(const TableauPile(0), 0, const TableauPile(1));
      expect(t.ticks, 1);
      c.dispose();
    });

    test('the illegal second tap of a two-tap move: one tick', () {
      final (c, _, t) = playing(stuck);
      c.tapPile(const TableauPile(0), 0);
      expect(t.ticks, 0, reason: 'selecting is not a refusal');
      c.tapPile(const TableauPile(1), 0);
      expect(t.ticks, 1);
      c.dispose();
    });

    test('an empty stock and waste tapped: one tick', () {
      final (c, _, t) = playing(stuck);
      c.tapPile(const StockPile(), null);
      expect(t.ticks, 1);
      c.dispose();
    });

    test('a refused Spider deal: one tick', () {
      final (c, _, t) = playing(dealRefused);
      c.dealRow();
      expect(t.ticks, 1);
      c.dispose();
    });

    test('a Spider run completing: one tick, and the same when it wins', () {
      var (c, _, t) = playing(oneFromRun);
      c.move(const TableauPile(1), 0, const TableauPile(0));
      expect(
        c.game is SpiderGame && (c.game as SpiderGame).completed.length == 1,
        isTrue,
      );
      expect(t.ticks, 1);
      c.dispose();
      (c, _, t) = playing(
        spider(
          tableau: [
            kingDown(Suit.spades, 2),
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
          completed: List.filled(7, Suit.spades),
        ),
      );
      c.move(const TableauPile(1), 0, const TableauPile(0));
      expect(c.game.isWon, isTrue);
      expect(t.ticks, 1, reason: 'the winning step ticks once');
      c.dispose();
    });

    test('a Klondike foundation reaching its King: one tick', () {
      final (c, _, t) = playing(oneFromFoundation);
      c.move(const TableauPile(0), 0, const FoundationPile(Suit.spades));
      expect(t.ticks, 1);
      c.dispose();
    });

    test(
      'the peek ticks once per start, not on a column with nothing to fan',
      () {
        final (c, _, t) = playing(oneMoveFromSolved);
        c.startPeek(0);
        expect(t.ticks, 1);
        c.endPeek();
        c.startPeek(3); // empty column: nothing to peek
        expect(t.ticks, 1);
        c.dispose();
      },
    );

    test('undo, restart, resume and a new deal never tick', () {
      final (c, _, t) = playing(oneFromFoundation);
      c.move(const TableauPile(1), 0, const TableauPile(2)); // KH to empty
      expect(t.ticks, 0);
      c.undo();
      c.pause();
      c.resume();
      c.restart();
      c.newDeal();
      expect(t.ticks, 0);
      c.dispose();
    });

    testWidgets(
      'the finish sweep ticks on the steps that complete a foundation',
      (tester) async {
        final (c, f, t) = playing(oneMoveFromSolved);
        c.move(const WastePile(), 0, const FoundationPile(Suit.clubs));
        expect(c.finishing, isTrue, reason: 'auto-finish sweeps the rest');
        await tester.pump(sweepStep * 40);
        expect(c.game.isWon, isTrue);
        // Two foundations were complete already; the sweep finishes the
        // other two: two Kings land, two ticks, nothing for the other steps.
        expect(t.ticks, 2);
        expect(f.ticks, 2);
        c.dispose();
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  group('the Haptics setting', () {
    testWidgets(
      'restored on at launch: no tick; turned on by the player: exactly one light impact',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final store = AppStore.memory();
        await store.write(StoreDoc.settings, {'haptics': true, 'sound': false});
        await tester.pumpWidget(
          HonestSolitaireApp(
            store: store,
            showSplash: false,
            sound: const NoSoundPlayer(),
            dealNumberSource: () => DealNumber(3),
          ),
        );
        await tester.pump();
        await tester.pump();
        final scope = tester.widget<GameScope>(find.byType(GameScope));
        expect(scope.settingsStore.loaded, isTrue);
        expect(scope.playSettings.value.haptics, isTrue, reason: 'restored');
        final haptic = calls.where((c) => c.method == 'HapticFeedback.vibrate');
        expect(haptic, isEmpty, reason: 'a restore is not the player');
        scope.playSettings.value = scope.playSettings.value.copyWith(
          haptics: false,
        );
        await tester.pump();
        expect(haptic, isEmpty, reason: 'turning it off is silent');
        scope.playSettings.value = scope.playSettings.value.copyWith(
          haptics: true,
        );
        await tester.pump();
        expect(haptic.map((c) => c.arguments), [
          'HapticFeedbackType.lightImpact',
        ]);
      },
    );
  });
}
