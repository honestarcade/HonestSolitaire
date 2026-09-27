import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/game/finish_sweep.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';
import 'package:honest_solitaire/ui/motion.dart';
import 'package:honest_solitaire/ui/navigation.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

import 'disposing_host.dart';
import 'win_fixtures.dart';

/// The phone's switch: on for every test by default (flutter_test_config);
/// these tests set it per case.
void phoneAnimations(WidgetTester tester, {required bool removed}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: removed);
}

Future<GameScope> pumpApp(
  WidgetTester tester, {
  bool cardAnimations = true,
  bool removed = false,
  AppStore? store,
}) async {
  phoneAnimations(tester, removed: removed);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: store ?? AppStore.memory(),
      showSplash: false,
      initialPlaySettings: PlaySettings(cardAnimations: cardAnimations),
    ),
  );
  await tester.pump();
  await tester.pump();
  return tester.widget<GameScope>(find.byType(GameScope));
}

NavigatorState navigatorOf(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

/// The opacity the route's own fade gives [screen]: the outer of the two
/// FadeTransitions FadePageRoute wraps the page in.
double routeOpacity(WidgetTester tester, Type screen) {
  final fades = find.ancestor(
    of: find.byType(screen),
    matching: find.byType(FadeTransition),
  );
  return tester.widget<FadeTransition>(fades.last).opacity.value;
}

GameController controllerFor(Game game, {bool cardAnimations = true}) =>
    GameController(
      game,
      ValueNotifier(
        PlaySettings(oneTap: false, cardAnimations: cardAnimations),
      ),
      ValueNotifier(const DisplayOptions()),
    );

Future<void> pumpBoard(
  WidgetTester tester,
  GameController controller, {
  bool removed = false,
}) async {
  phoneAnimations(tester, removed: removed);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DisposingHost(
        controller: controller,
        child: BoardView(controller: controller),
      ),
    ),
  );
}

double cardOpacity(WidgetTester tester, String key) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(Key(key)),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('screens cross-fade', () {
    testWidgets(
      'a pushed screen is partly transparent at 100 ms and opaque at 200 ms; the menu fades out beneath it',
      (tester) async {
        final scope = await pumpApp(tester);
        final navigator = navigatorOf(tester);
        scope.navigating.push(
          navigator,
          FadePageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        await tester.pump();
        await tester.pump(); // the page builds a frame after the push
        expect(routeOpacity(tester, SettingsScreen), 0);
        expect(scope.navigating.busy, isTrue);
        await tester.pump(const Duration(milliseconds: 100));
        final mid = routeOpacity(tester, SettingsScreen);
        expect(mid, greaterThan(0.2));
        expect(mid, lessThan(0.8));
        expect(
          find.byKey(const Key('menu-settings')),
          findsOneWidget,
          reason: 'the menu is still painted mid-fade',
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(routeOpacity(tester, SettingsScreen), 1);
        // The controller reports completed at the tick after it lands.
        await tester.pump(const Duration(milliseconds: 1));
        expect(scope.navigating.busy, isFalse);

        // The pop reverses over the same time.
        scope.navigating.pop(navigator.context);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final back = routeOpacity(tester, SettingsScreen);
        expect(back, greaterThan(0.2));
        expect(back, lessThan(0.8));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(scope.navigating.busy, isFalse);
      },
    );

    testWidgets('with Card animations off the fade is 100 ms', (tester) async {
      final scope = await pumpApp(tester, cardAnimations: false);
      scope.navigating.push(
        navigatorOf(tester),
        FadePageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final mid = routeOpacity(tester, SettingsScreen);
      expect(mid, greaterThan(0.2));
      expect(mid, lessThan(0.8));
      await tester.pump(const Duration(milliseconds: 50));
      expect(routeOpacity(tester, SettingsScreen), 1);
    });

    testWidgets(
      'with the phone removing animations the first frame is the final one and navigating clears at once',
      (tester) async {
        final scope = await pumpApp(tester, removed: true);
        final navigator = navigatorOf(tester);
        scope.navigating.push(
          navigator,
          FadePageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        await tester.pump();
        await tester.pump();
        expect(routeOpacity(tester, SettingsScreen), 1);
        expect(
          scope.navigating.busy,
          isFalse,
          reason: 'a zero-duration push is done when it is made',
        );
        expect(scope.navigating.pop(navigator.context), isTrue);
        await tester.pump();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(scope.navigating.busy, isFalse);
      },
    );

    testWidgets('the menu route (home) fades under a pushed screen too', (
      tester,
    ) async {
      final scope = await pumpApp(tester);
      scope.navigating.push(
        navigatorOf(tester),
        FadePageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The home route's transitions come from the theme's backstop: its
      // page sits under a FadeTransition driven by the pushed route.
      final menuFades = find.ancestor(
        of: find.byKey(const Key('menu-settings')),
        matching: find.byType(FadeTransition),
      );
      final values = [
        for (final f in tester.widgetList<FadeTransition>(menuFades))
          f.opacity.value,
      ];
      expect(
        values.any((v) => v > 0.2 && v < 0.8),
        isTrue,
        reason: 'the menu is mid-fade: $values',
      );
    });
  });

  group('the cards rise', () {
    testWidgets(
      'the pause card is 8 px low and transparent at 0 ms and settled at 350 ms',
      (tester) async {
        final controller = controllerFor(oneMoveFromSolved);
        await pumpBoard(tester, controller);
        controller.pause();
        await tester.pump();
        final start = tester.getTopLeft(find.byKey(const Key('pause-card')));
        expect(cardOpacity(tester, 'scrim'), 0);
        await tester.pump(const Duration(milliseconds: 175));
        final mid = tester.getTopLeft(find.byKey(const Key('pause-card')));
        expect(mid.dy, lessThan(start.dy));
        final o = cardOpacity(tester, 'scrim');
        expect(o, greaterThan(0));
        expect(o, lessThan(1));
        await tester.pump(const Duration(milliseconds: 175));
        final end = tester.getTopLeft(find.byKey(const Key('pause-card')));
        expect(start.dy - end.dy, closeTo(riseFor(390), 0.01));
        expect(cardOpacity(tester, 'scrim'), 1);
        // Buttons take input during the rise: Resume works at once.
        controller.resume();
        await tester.pump();
        controller.pause();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Resume'));
        await tester.pump();
        expect(controller.isPaused, isFalse);
      },
    );

    testWidgets('the win card rises the same way once the cascade is skipped', (
      tester,
    ) async {
      final controller = controllerFor(nearWin(const KlondikeOptions()));
      await pumpBoard(tester, controller);
      controller.move(
        const TableauPile(0),
        0,
        const FoundationPile(Suit.clubs),
      );
      await tester.pump();
      await tester.pump(winCardDelay);
      for (var i = 0; i < 10 && !controller.winPending; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(const Offset(195, 500)); // skip the cascade
      await tester.pump();
      expect(controller.winShown, isTrue);
      final start = tester.getTopLeft(find.byKey(const Key('win-card')));
      expect(cardOpacity(tester, 'scrim'), 0);
      await tester.pump(const Duration(milliseconds: 350));
      final end = tester.getTopLeft(find.byKey(const Key('win-card')));
      expect(start.dy - end.dy, closeTo(riseFor(390), 0.01));
      expect(cardOpacity(tester, 'scrim'), 1);
    });

    testWidgets('Card animations off: a 100 ms fade with no rise', (
      tester,
    ) async {
      final controller = controllerFor(
        oneMoveFromSolved,
        cardAnimations: false,
      );
      await pumpBoard(tester, controller);
      controller.pause();
      await tester.pump();
      final start = tester.getTopLeft(find.byKey(const Key('pause-card')));
      expect(cardOpacity(tester, 'scrim'), 0);
      await tester.pump(const Duration(milliseconds: 50));
      final o = cardOpacity(tester, 'scrim');
      expect(o, greaterThan(0));
      expect(o, lessThan(1));
      expect(tester.getTopLeft(find.byKey(const Key('pause-card'))), start);
      await tester.pump(const Duration(milliseconds: 50));
      expect(cardOpacity(tester, 'scrim'), 1);
    });

    testWidgets('the phone removing animations: the first frame is final', (
      tester,
    ) async {
      final controller = controllerFor(oneMoveFromSolved);
      await pumpBoard(tester, controller, removed: true);
      controller.pause();
      await tester.pump();
      final start = tester.getTopLeft(find.byKey(const Key('pause-card')));
      expect(cardOpacity(tester, 'scrim'), 1);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getTopLeft(find.byKey(const Key('pause-card'))), start);
    });
  });

  group('the Settings switch', () {
    Offset knobOf(WidgetTester tester, String field) => tester.getCenter(
      find.descendant(
        of: find.byKey(Key('settings-row-$field')),
        matching: find.byKey(const Key('switch-knob')),
      ),
    );

    Color trackOf(WidgetTester tester, String field) {
      final box = find
          .descendant(
            of: find.descendant(
              of: find.byKey(Key('settings-row-$field')),
              matching: find.byKey(const Key('switch')),
            ),
            matching: find.byType(DecoratedBox),
          )
          .first;
      return (tester.widget<DecoratedBox>(box).decoration as BoxDecoration)
          .color!;
    }

    testWidgets(
      'the knob is between the ends at 75 ms and at the end at 150 ms, the track colour with it',
      (tester) async {
        final scope = await pumpApp(tester);
        scope.navigating.push(
          navigatorOf(tester),
          FadePageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        const field = 'winnableOnly';
        expect(scope.playSettings.value.winnableOnly, isFalse);
        final off = knobOf(tester, field);
        final offColour = trackOf(tester, field);
        await tester.tap(find.byKey(const Key('settings-row-$field')));
        await tester.pump();
        expect(scope.playSettings.value.winnableOnly, isTrue);
        await tester.pump(const Duration(milliseconds: 75));
        final mid = knobOf(tester, field);
        expect(mid.dx, greaterThan(off.dx + 2));
        await tester.pump(const Duration(milliseconds: 75));
        final on = knobOf(tester, field);
        expect(on.dx, greaterThan(mid.dx + 2), reason: 'still moving at 75 ms');
        expect(on.dx - off.dx, closeTo(20, 0.5), reason: '46 − 26 at scale 1');
        expect(trackOf(tester, field), isNot(offColour));
        // A second toggle reverses from where it is.
        await tester.tap(find.byKey(const Key('settings-row-$field')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));
        final back = knobOf(tester, field);
        expect(back.dx, lessThan(on.dx - 2));
        expect(back.dx, greaterThan(off.dx + 2));
      },
    );

    testWidgets('a value restored at build does not animate', (tester) async {
      final store = AppStore.memory();
      final scope = await pumpApp(tester, store: store);
      scope.playSettings.value = scope.playSettings.value.copyWith(
        winnableOnly: true,
      );
      await tester.pump();
      scope.navigating.push(
        navigatorOf(tester),
        FadePageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump();
      final first = knobOf(tester, 'winnableOnly');
      final track = tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('settings-row-winnableOnly')),
          matching: find.byKey(const Key('switch')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(knobOf(tester, 'winnableOnly'), first, reason: 'already there');
      expect(
        first.dx - track.dx,
        closeTo(10, 0.5),
        reason: 'on sits at the right end from the first frame',
      );
    });

    testWidgets('with the phone removing animations the knob jumps', (
      tester,
    ) async {
      final scope = await pumpApp(tester, removed: true);
      scope.navigating.push(
        navigatorOf(tester),
        FadePageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump();
      const field = 'winnableOnly';
      final off = knobOf(tester, field);
      await tester.tap(find.byKey(const Key('settings-row-$field')));
      await tester.pump();
      expect(knobOf(tester, field).dx - off.dx, closeTo(20, 0.5));
    });
  });
}
