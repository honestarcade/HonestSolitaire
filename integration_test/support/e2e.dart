// Shared driving for the on-device end-to-end suite (#112): launching the
// real app, reaching screens by their keys, and playing engine moves as real
// taps on the board. Run by tools/e2e.sh, never by the gate.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/main.dart' as app;
import 'package:honest_solitaire/ui/app.dart';

/// Which half of a two-phase run this is: 1 plays and backgrounds, 2
/// restores after the script has force-stopped the app.
const int e2ePhase = int.fromEnvironment('E2E_PHASE', defaultValue: 1);

/// Phase 1's elapsed time at backgrounding, handed to phase 2 by the script.
const int e2eElapsedMs = int.fromEnvironment(
  'E2E_ELAPSED_MS',
  defaultValue: -1,
);

/// Wall-clock stamps for synthesised taps: the controller's double-tap
/// window and Spider's deal debounce read the pointer's timestamp, and
/// `tester.tapAt` stamps every tap zero.
final Stopwatch _clock = Stopwatch()..start();

GameScope scope(WidgetTester t) => t.widget<GameScope>(find.byType(GameScope));

Future<void> wait(WidgetTester t, int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

/// Pumps until [finder] matches, failing after [seconds].
Future<void> waitFor(WidgetTester t, Finder finder, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('e2e: timed out after ${seconds}s waiting for $finder');
    }
    await wait(t, 100);
  }
}

/// Waits until [finder] matches nothing, failing after [seconds].
Future<void> waitGone(WidgetTester t, Finder finder, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('e2e: timed out after ${seconds}s waiting for $finder to go');
    }
    await wait(t, 100);
  }
}

Future<void> launch(WidgetTester t) async {
  app.main();
  // The menu is built under the splash while it fades; a tap before the
  // splash is gone lands on the splash.
  await waitFor(t, find.byKey(const Key('menu-resume')), seconds: 60);
  await waitGone(t, find.byKey(const Key('launch-splash')), seconds: 60);
  await wait(t, 500);
}

Future<void> tapAt(WidgetTester t, Offset p) async {
  final g = await t.createGesture();
  await g.down(p, timeStamp: _clock.elapsed);
  await g.up(timeStamp: _clock.elapsed);
  await wait(t, 50);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await waitFor(t, f);
  await t.ensureVisible(f.first);
  await wait(t, 50);
  await tapAt(t, t.getCenter(f.first));
  await wait(t, 250);
}

/// Sets a Settings row to [on] by tapping it, only if it differs.
Future<void> setSetting(WidgetTester t, String field, bool on) async {
  final s = scope(t);
  bool now() => switch (field) {
    'oneTap' => s.playSettings.value.oneTap,
    'autoFinish' => s.playSettings.value.autoFinish,
    'cardAnimations' => s.playSettings.value.cardAnimations,
    'sound' => s.playSettings.value.sound,
    'music' => s.playSettings.value.music,
    _ => throw ArgumentError(field),
  };
  if (now() == on) return;
  await tapKey(t, 'settings-row-$field');
  expect(now(), on, reason: 'e2e: Settings row $field did not change');
}

/// The test's fixed settings, set through the real Settings screen: moves
/// by select-then-tap, no card animation, silent, and FINISH by hand.
Future<void> configure(WidgetTester t) async {
  await tapKey(t, 'menu-settings');
  await setSetting(t, 'oneTap', false);
  await setSetting(t, 'cardAnimations', false);
  await setSetting(t, 'sound', false);
  await setSetting(t, 'music', false);
  await setSetting(t, 'autoFinish', false);
  await tapKey(t, 'settings-back');
  await waitFor(t, find.byKey(const Key('menu-resume')));
}

Future<void> typeDealNumber(WidgetTester t, DealNumber n) async {
  final field = find.descendant(
    of: find.byKey(const Key('deal-number-field')),
    matching: find.byType(EditableText),
  );
  await waitFor(t, field);
  await t.ensureVisible(field);
  await t.enterText(field, '${n.value}');
  await wait(t, 200);
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(t, 200);
}

Rect rectOfKey(WidgetTester t, String key) => t.getRect(find.byKey(Key(key)));

/// Taps a card in a pile by its visible top strip, which is where a fanned
/// card can be hit under the ones on top of it.
Future<void> tapCard(WidgetTester t, String pile, int index) async {
  final r = rectOfKey(t, 'card-$pile-$index');
  await tapAt(t, Offset(r.center.dx, r.top + 4));
}

Future<void> tapColumn(WidgetTester t, List<Card> column, int c) async {
  if (column.isEmpty) {
    await tapAt(t, rectOfKey(t, 'slot-t$c').center);
  } else {
    await tapCard(t, 't$c', column.length - 1);
  }
}

/// The comparable part of a game: everything but the clock and the
/// undo-just-happened flag, which a replay of the same moves never sets.
Map<String, Object?> state(Game g) => g.toJson()
  ..remove('elapsedMs')
  ..remove('lastUndone');

Game after(Game g, Move m) => switch (g.apply(m)) {
  Applied(:final game) => game,
  Refused(:final reason) => fail('e2e: the engine refused $m: $reason'),
};

/// Plays [m] on the board by real taps and checks the board took exactly
/// that move. Waits past the double-tap window first, so two moves on one
/// pile are never read as a double tap.
Future<void> playMove(WidgetTester t, Move m) async {
  await wait(t, 350);
  final c = scope(t).controller;
  final g = c.game;
  final expected = state(after(g, m));
  switch ((g, m)) {
    case (KlondikeGame _, Draw() || Recycle()):
      await tapAt(t, rectOfKey(t, 'slot-stock').center);
    case (KlondikeGame k, WasteToTableau(:final to)):
      await tapAt(t, rectOfKey(t, 'slot-waste').center);
      await tapColumn(t, k.tableau[to], to);
    case (KlondikeGame k, WasteToFoundation()):
      final suit = k.waste.last.suit;
      await tapAt(t, rectOfKey(t, 'slot-waste').center);
      await tapAt(t, rectOfKey(t, 'slot-f-${suit.name}').center);
    case (KlondikeGame k, TableauToFoundation(:final from)):
      final suit = k.tableau[from].last.suit;
      await tapCard(t, 't$from', k.tableau[from].length - 1);
      await tapAt(t, rectOfKey(t, 'slot-f-${suit.name}').center);
    case (KlondikeGame k, MoveRun(:final from, :final start, :final to)):
      await tapCard(t, 't$from', start);
      await tapColumn(t, k.tableau[to], to);
    case (KlondikeGame k, FoundationToTableau(:final foundation, :final to)):
      await tapAt(
        t,
        rectOfKey(t, 'slot-f-${Suit.values[foundation].name}').center,
      );
      await tapColumn(t, k.tableau[to], to);
    case (KlondikeGame k, Flip(:final column)):
      await tapCard(t, 't$column', k.tableau[column].length - 1);
    case (SpiderGame s, MoveCards(:final from, :final start, :final to)):
      await tapCard(t, 't$from', start);
      await tapColumn(t, s.tableau[to], to);
    case (SpiderGame _, DealRow()):
      await tapAt(t, rectOfKey(t, 'stock-sliver-0').center);
    default:
      fail('e2e: no taps for $m on ${g.runtimeType}');
  }
  await wait(t, 150);
  expect(
    state(c.game),
    expected,
    reason: 'e2e: the board did not play $m as the engine does',
  );
  expect(c.selection, isNull, reason: 'e2e: a selection was left after $m');
}

/// Taps the selected card again to clear a selection a refusal left behind.
Future<void> clearSelection(WidgetTester t) async {
  final c = scope(t).controller;
  final sel = c.selection;
  if (sel == null) return;
  await wait(t, 350);
  await tapCard(t, sel.$1.token, sel.$2);
  expect(c.selection, isNull, reason: 'e2e: could not clear the selection');
}

/// Sends the real lifecycle messages a Home press produces, so the app's
/// own background handling (the save flush among it) runs, then returns
/// the app to the foreground so the test can end. Nothing pumps while the
/// app is paused: a paused app draws no frames, and a pump would wait for
/// one forever. Returns the game's elapsed time at backgrounding.
Future<int> background(WidgetTester t) async {
  Future<void> send(AppLifecycleState s) async {
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(s.toString()),
      (_) {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    await send(s);
  }
  await Future<void>.delayed(const Duration(seconds: 2));
  final elapsed = scope(t).controller.game.elapsed.inMilliseconds;
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    await send(s);
  }
  await wait(t, 300);
  return elapsed;
}

/// The line tools/e2e.sh waits for before it force-stops the app.
void phaseOneDone(int elapsedMs) {
  // ignore: avoid_print
  print('E2E_PHASE1_DONE E2E_ELAPSED_MS=$elapsedMs');
}

/// The menu's resume button label: "New game" when nothing is resumable.
String resumeLabel(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('menu-resume-label'))).data ?? '';
