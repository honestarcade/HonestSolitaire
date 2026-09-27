import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/screens/loading_screen.dart';
import 'package:honest_solitaire/ui/screens/menu_screen.dart';

/// A dealer the test drives by hand.
class FakeDealer implements DealerHandle {
  FakeDealer(this.base, this.options);

  final DealNumber base;
  final KlondikeOptions options;
  final controller = StreamController<DealerEvent>();
  int cancels = 0;

  @override
  Stream<DealerEvent> get events => controller.stream;

  /// Marks the cancel and emits `Cancelled`; the stream stays open so a
  /// test can push a late event through it.
  @override
  Future<void> cancel() async {
    cancels++;
    controller.add(const Cancelled());
  }

  void emit(DealerEvent e) => controller.add(e);
}

class Searches {
  final List<FakeDealer> started = [];
  DealerHandle start(DealNumber base, KlondikeOptions options) {
    final d = FakeDealer(base, options);
    started.add(d);
    return d;
  }
}

const options = KlondikeOptions(
  draw: DrawMode.one,
  scoring: ScoringMode.vegas,
  timed: false,
);

/// Pumps the app without its splash, then pushes the search screen.
Future<(GameScope, Searches)> openSearch(
  WidgetTester tester, {
  List<int> numbers = const [5, 900, 901],
  bool settleTransition = true,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final searches = Searches();
  var i = 0;
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: AppStore.memory(),
      showSplash: false,
      search: searches.start,
      dealNumberSource: () => DealNumber(numbers[i++ % numbers.length]),
    ),
  );
  await tester.pump();
  final scope = tester.widget<GameScope>(find.byType(GameScope));
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => const LoadingScreen.search(options: options),
        ),
      );
  await settle(tester, transition: settleTransition);
  return (scope, searches);
}

/// Two pumps: the first flushes the microtasks that call setState, the
/// second draws the frame. [transition] covers a route animation; the
/// search bar loops forever, so `pumpAndSettle` cannot be used here.
Future<void> settle(WidgetTester tester, {bool transition = false}) async {
  await tester.pump();
  await tester.pump();
  if (transition) {
    // Android's page transition runs 800 ms in this Flutter.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
  }
}

String label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('loading-label'))).data!;
double? barTarget(WidgetTester tester) =>
    tester.widget<LoadingBar>(find.byKey(const Key('loading-bar'))).fraction;

void main() {
  group('launch', () {
    // READY's hold and the fade are motion (#105): these assert the design
    // timings, so the phone's switch is off here (on for every test by
    // default); the last test covers the switch on.
    setUp(() {
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
    });
    testWidgets(
      'progresses through the three labels as each load completes, never early, and stays at least 600 ms',
      (tester) async {
        final gates = [Completer<void>(), Completer<void>(), Completer<void>()];
        var done = false;
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingScreen.launch(
              steps: [
                LaunchStep('SHUFFLING', () => gates[0].future),
                LaunchStep('DEALING', () => gates[1].future),
                LaunchStep('READY', () => gates[2].future),
              ],
              onDone: () => done = true,
            ),
          ),
        );
        expect(label(tester), 'SHUFFLING');
        expect(barTarget(tester), 0);
        expect(find.text('BY HONEST ARCADE'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Loading Honest Solitaire'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(
          label(tester),
          'SHUFFLING',
          reason: 'a slow step does not advance the bar',
        );
        expect(barTarget(tester), 0);
        gates[0].complete();
        await settle(tester);
        expect(label(tester), 'DEALING');
        expect(barTarget(tester), closeTo(1 / 3, 1e-9));
        gates[1].complete();
        await settle(tester);
        expect(label(tester), 'READY');
        expect(barTarget(tester), closeTo(2 / 3, 1e-9));
        gates[2].complete();
        await settle(tester);
        expect(barTarget(tester), 1);
        expect(label(tester), 'READY');
        // Minimum already passed (2 s); READY holds 350 ms then fades 200 ms.
        await tester.pump(const Duration(milliseconds: 300));
        expect(done, isFalse);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        expect(done, isTrue);
      },
    );

    testWidgets(
      'loads that finish at once still show the splash for 600 ms; a hung step times out after 5 s',
      (tester) async {
        var done = false;
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingScreen.launch(
              steps: [
                LaunchStep('SHUFFLING', () async {}),
                LaunchStep('DEALING', () => Completer<void>().future),
                LaunchStep('READY', () async {}),
              ],
              onDone: () => done = true,
            ),
          ),
        );
        await tester.pump();
        expect(label(tester), 'DEALING');
        await tester.pump(const Duration(seconds: 4));
        expect(label(tester), 'DEALING');
        await tester.pump(const Duration(milliseconds: 1100));
        expect(label(tester), 'READY', reason: 'the hung step was skipped');
        expect(barTarget(tester), 1);
        expect(done, isFalse);
        await tester.pump(const Duration(milliseconds: 600));
        expect(done, isTrue);
      },
    );

    testWidgets(
      'with the phone removing animations READY does not hold and the fade is instant',
      (tester) async {
        TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        var done = false;
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingScreen.launch(
              steps: [
                LaunchStep('SHUFFLING', () async {}),
                LaunchStep('DEALING', () async {}),
                LaunchStep('READY', () async {}),
              ],
              onDone: () => done = true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 599));
        expect(done, isFalse, reason: 'the 600 ms minimum is display time');
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();
        expect(done, isTrue, reason: 'no hold, no fade');
      },
    );

    testWidgets(
      'the app shows the splash over the board and removes it once the loads finish',
      (tester) async {
        await tester.pumpWidget(
          HonestSolitaireApp(
            store: AppStore.memory(),
            dealNumberSource: () => DealNumber(3),
          ),
        );
        expect(find.byKey(const Key('launch-splash')), findsOneWidget);
        expect(
          find.byType(MenuScreen),
          findsOneWidget,
          reason: 'built underneath from the start',
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byKey(const Key('launch-splash')),
          findsOneWidget,
          reason: 'under 600 ms',
        );
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('launch-splash')), findsNothing);
        final scope = tester.widget<GameScope>(find.byType(GameScope));
        expect(scope.settingsStore.loaded, isTrue);
        expect(scope.stats.loaded, isTrue);
      },
    );
  });

  group('search', () {
    testWidgets('shows the count, and Cancel cancels the dealer and returns', (
      tester,
    ) async {
      final (scope, searches) = await openSearch(tester);
      expect(searches.started, hasLength(1));
      final dealer = searches.started.single;
      expect(
        dealer.base.value,
        900,
        reason: 'the base comes from the deal-number source',
      );
      expect(dealer.options, options);
      expect(label(tester), 'FINDING A WINNABLE DEAL');
      expect(
        tester.widget<Text>(find.byKey(const Key('loading-count'))).data,
        '',
      );
      dealer.emit(const Progress(1, Duration(milliseconds: 100)));
      await settle(tester);
      expect(find.text('1 deal tried'), findsOneWidget);
      dealer.emit(const Progress(1412, Duration(seconds: 2)));
      await settle(tester);
      expect(find.text('1,412 deals tried'), findsOneWidget);
      final before = scope.controller.game;
      await tester.tap(find.byKey(const Key('loading-cancel')));
      await settle(tester, transition: true);
      expect(dealer.cancels, 1);
      expect(find.byType(LoadingScreen), findsNothing);
      expect(
        scope.controller.game,
        before,
        reason: 'the previous game is untouched',
      );
    });

    testWidgets(
      'the soft limit offers both choices; Keep searching hides them and a Found opens the board on that deal',
      (tester) async {
        final (scope, searches) = await openSearch(tester);
        final dealer = searches.started.single;
        dealer.emit(const SoftLimitReached());
        await settle(tester);
        expect(find.byKey(const Key('loading-keep')), findsOneWidget);
        expect(find.byKey(const Key('loading-random')), findsOneWidget);
        expect(find.byKey(const Key('loading-cancel')), findsNothing);
        await tester.tap(find.byKey(const Key('loading-keep')));
        await tester.pump();
        expect(find.byKey(const Key('loading-keep')), findsNothing);
        expect(find.byKey(const Key('loading-cancel')), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        expect(
          find.byKey(const Key('loading-keep')),
          findsOneWidget,
          reason: 'offered again after 10 s',
        );
        await tester.tap(find.byKey(const Key('loading-keep')));
        await tester.pump();
        final found = KlondikeGame.deal(DealNumber(777), options);
        dealer.emit(Found(found, const []));
        await settle(tester, transition: true);
        expect(find.byType(LoadingScreen), findsNothing);
        expect(find.byType(BoardView), findsOneWidget);
        expect(scope.controller.game.dealNumber.value, 777);
        expect((scope.controller.game as KlondikeGame).options, options);
        expect(find.text('Klondike · draw 1'), findsOneWidget);
      },
    );

    testWidgets(
      'Deal a random game instead cancels the search and deals a non-winnable game with the same options',
      (tester) async {
        final (scope, searches) = await openSearch(
          tester,
          numbers: [5, 900, 5, 42],
        );
        final dealer = searches.started.single;
        dealer.emit(const SoftLimitReached());
        await settle(tester);
        await tester.tap(find.byKey(const Key('loading-random')));
        await settle(tester, transition: true);
        expect(dealer.cancels, 1);
        final game = scope.controller.game as KlondikeGame;
        expect(game.winnable, isFalse);
        expect(game.options, options);
        expect(
          game.dealNumber.value,
          42,
          reason: '5 equals the current game and is rerolled',
        );
        expect(find.byType(BoardView), findsOneWidget);
        // A late Found is ignored.
        dealer.emit(
          Found(KlondikeGame.deal(DealNumber(777), options), const []),
        );
        await settle(tester, transition: true);
        expect(scope.controller.game.dealNumber.value, 42);
      },
    );

    testWidgets(
      'NotFound shows the fallback with random-instead and Back; system back cancels',
      (tester) async {
        final (_, searches) = await openSearch(tester);
        final dealer = searches.started.single;
        dealer.emit(const NotFound());
        await settle(tester);
        expect(label(tester), 'No winnable deal found');
        expect(find.byKey(const Key('loading-random')), findsOneWidget);
        expect(find.byKey(const Key('loading-back')), findsOneWidget);
        expect(
          tester
              .widget<LoadingBar>(find.byKey(const Key('loading-bar')))
              .running,
          isFalse,
        );
        await tester.binding.handlePopRoute();
        await settle(tester, transition: true);
        expect(find.byType(LoadingScreen), findsNothing);
      },
    );

    testWidgets(
      'a Found inside 300 ms still shows the screen for 300 ms, and Cancel inside it wins',
      (tester) async {
        // The push transition (800 ms) is still running: the minimum counts
        // from the screen's first frame, and system back is the way out
        // while pointer events are ignored.
        final (scope, searches) = await openSearch(
          tester,
          settleTransition: false,
        );
        final dealer = searches.started.single;
        dealer.emit(
          Found(KlondikeGame.deal(DealNumber(777), options), const []),
        );
        await settle(tester);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(LoadingScreen), findsOneWidget);
        expect(scope.controller.game.dealNumber.value, 5);
        await tester.binding.handlePopRoute();
        await settle(tester, transition: true);
        expect(find.byType(LoadingScreen), findsNothing);
        expect(
          scope.controller.game.dealNumber.value,
          5,
          reason: 'the Found was dropped',
        );
      },
    );
  });
}
