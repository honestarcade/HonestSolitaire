import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/app_version.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/data/settings_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/navigation.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/screens/settings_screen.dart';
import 'package:honest_solitaire/ui/settings/display_options.dart';
import 'package:honest_solitaire/ui/settings/play_settings.dart';

/// Pumps the app on the board, then pushes the Settings screen over it.
Future<GameScope> openSettings(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    HonestSolitaireApp(
      store: store,
      showSplash: false,
      dealNumberSource: () => DealNumber(5),
    ),
  );
  await tester.pump();
  final scope = tester.widget<GameScope>(find.byType(GameScope));
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  // A board under Settings, as the pause card opens it (#93).
  navigator.push(boardRoute());
  await tester.pumpAndSettle();
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
  );
  await tester.pumpAndSettle();
  return scope;
}

Future<void> tapRow(WidgetTester tester, String field) async {
  await tester.ensureVisible(find.byKey(Key('settings-row-$field')));
  await tester.tap(find.byKey(Key('settings-row-$field')));
  await tester.pump();
}

void main() {
  testWidgets(
    'every row renders with the design default; the note, the version and the swatches are there',
    (tester) async {
      final store = AppStore.memory();
      final scope = await openSettings(tester, store);
      for (final row in [...playRows, ...displayRows, ...soundRows]) {
        await tester.ensureVisible(
          find.byKey(Key('settings-row-${row.field}')),
        );
        expect(find.text(row.label), findsOneWidget, reason: row.field);
        expect(find.text(row.description), findsOneWidget, reason: row.field);
        final expected = settingValue(
          row.field,
          const PlaySettings(),
          const DisplayOptions(),
        );
        final row_ = find.byKey(Key('settings-row-${row.field}'));
        final track = tester.widget<AnimatedContainer>(
          find.descendant(of: row_, matching: find.byKey(const Key('switch'))),
        );
        expect(
          track.alignment,
          expected ? Alignment.centerRight : Alignment.centerLeft,
          reason: row.field,
        );
      }
      expect(find.text('NAVY'), findsOneWidget);
      expect(find.text('TEAL'), findsOneWidget);
      expect(find.text('VIOLET'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('settings-version')));
      expect(find.text('v$appVersion · BUILD $appBuild'), findsOneWidget);
      expect(appVersion, 'dev', reason: 'no define in a test run');
      expect(find.text(storedNote), findsOneWidget);
      expect(find.text('STORED ON DEVICE ONLY'), findsOneWidget);
      expect(scope.playSettings.value, const PlaySettings());
    },
  );

  testWidgets(
    'toggling updates the notifier and the stored document; the board reflects it',
    (tester) async {
      final store = AppStore.memory();
      final scope = await openSettings(tester, store);
      await tapRow(tester, 'leftHanded');
      expect(scope.displayOptions.value.leftHanded, isTrue);
      await tapRow(tester, 'oneTap');
      expect(scope.playSettings.value.oneTap, isFalse);
      await tester.ensureVisible(
        find.byKey(const Key('settings-swatch-back-teal')),
      );
      await tester.tap(find.byKey(const Key('settings-swatch-back-teal')));
      await tester.pump();
      expect(scope.displayOptions.value.cardBack, CardBack.teal);
      await tester.pump(const Duration(seconds: 1));
      await store.flush();
      final saved = (await store.read(StoreDoc.settings) as Loaded).data;
      expect(saved['leftHanded'], isTrue);
      expect(saved['oneTap'], isFalse);
      expect(saved['cardBack'], 'teal');
      expect(saved['music'], isFalse);
      // The board behind shows the change on return.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      final stock = tester.getRect(
        find.byKey(const Key('card-stock-0'), skipOffstage: false),
      );
      expect(
        stock.left,
        greaterThan(200),
        reason: 'left-handed puts the stock on the right',
      );
    },
  );

  testWidgets('a relaunch over the same store restores every value', (
    tester,
  ) async {
    final store = AppStore.memory();
    final play = ValueNotifier(const PlaySettings());
    final display = ValueNotifier(const DisplayOptions());
    final settings = SettingsStore(
      store,
      play,
      display,
      observeLifecycle: false,
    );
    await settings.load();
    play.value = const PlaySettings(
      oneTap: false,
      autoFinish: false,
      autoFlip: false,
      unlimitedUndo: false,
      winnableOnly: true,
      cardAnimations: false,
      sound: false,
      music: true,
      haptics: false,
    );
    display.value = const DisplayOptions(
      leftHanded: true,
      largeCards: true,
      cardBack: CardBack.violet,
      showTimer: false,
      showMovesAndScore: false,
    );
    await settings.setLastKlondikeOptions(
      const KlondikeOptions(
        draw: DrawMode.one,
        scoring: ScoringMode.vegas,
        timed: false,
      ),
    );
    await settings.setLastSpiderOptions(
      const SpiderOptions(suits: SpiderSuits.four, relaxed: true, timed: false),
    );
    settings.flush();
    await store.flush();
    settings.dispose();
    final play2 = ValueNotifier(const PlaySettings());
    final display2 = ValueNotifier(const DisplayOptions());
    final again = SettingsStore(
      store,
      play2,
      display2,
      observeLifecycle: false,
    );
    await again.load();
    expect(play2.value, play.value);
    expect(display2.value, display.value);
    expect(
      again.lastKlondikeOptions,
      const KlondikeOptions(
        draw: DrawMode.one,
        scoring: ScoringMode.vegas,
        timed: false,
      ),
    );
    expect(
      again.lastSpiderOptions,
      const SpiderOptions(suits: SpiderSuits.four, relaxed: true, timed: false),
    );
    again.dispose();
  });

  test(
    'missing or bad fields fall back per field; a no-op change writes nothing',
    () async {
      final store = AppStore.memory();
      await store.write(StoreDoc.settings, {
        'oneTap': false,
        'cardBack': 'plaid',
        'largeCards': 'yes',
        'lastKlondikeOptions': {'draw': 'seven'},
      });
      final play = ValueNotifier(const PlaySettings());
      final display = ValueNotifier(const DisplayOptions());
      final settings = SettingsStore(
        store,
        play,
        display,
        observeLifecycle: false,
      );
      await settings.load();
      expect(play.value.oneTap, isFalse);
      expect(play.value.autoFinish, isTrue);
      expect(display.value.cardBack, CardBack.navy);
      expect(display.value.largeCards, isFalse);
      expect(settings.lastKlondikeOptions, firstRunKlondike);
      expect(settings.writes, 0, reason: 'loading writes nothing');
      play.value = play.value.copyWith(oneTap: false);
      await Future<void>.delayed(Duration.zero);
      expect(settings.writes, 0, reason: 'a no-op change writes nothing');
      play.value = play.value.copyWith(oneTap: true);
      await Future<void>.delayed(Duration.zero);
      expect(settings.writes, 1);
      settings.dispose();
    },
  );

  testWidgets(
    '"Applies to your next deal" shows under Auto-flip and Winnable only while a game is live',
    (tester) async {
      final store = AppStore.memory();
      final scope = await openSettings(tester, store);
      await tester.ensureVisible(
        find.byKey(const Key('settings-row-winnableOnly')),
      );
      expect(
        find.byKey(const Key('settings-note-autoFlip')),
        findsNothing,
        reason: 'no move yet',
      );
      scope.controller.tapPile(const StockPile(), null);
      await tester.pump();
      expect(find.byKey(const Key('settings-note-autoFlip')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-note-winnableOnly')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-note-oneTap')), findsNothing);
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(1)));
      scope.controller.tapPile(const StockPile(), null);
      await tester.pump();
      expect(find.byKey(const Key('settings-note-autoFlip')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-note-winnableOnly')),
        findsNothing,
        reason: 'Klondike only',
      );
    },
  );
}
