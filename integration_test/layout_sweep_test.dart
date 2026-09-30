// Every screen on a real device (#114), with Large cards off and on: no
// overflow the framework reports, no ellipsis outside #106's allowlist, and
// a screenshot of each for a human to judge against the test plan. Run by
// tools/layout.sh at the phone's default and largest font, never by the gate.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/solver.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

/// The font scale tools/layout.sh set, for the screenshot names.
const String fontTag = String.fromEnvironment(
  'LAYOUT_FONT',
  defaultValue: 'default',
);

/// #106's allowlist: the board title may ellipsize, nothing else may.
const ellipsisAllowed = {'board-title'};

const klondike = KlondikeOptions(draw: DrawMode.one, timed: false);

/// Every paragraph that ran out of lines outside the allowlist.
List<String> ellipsized() {
  final out = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached) continue;
    if (!render.didExceedMaxLines) continue;
    var allowed = false;
    element.visitAncestorElements((a) {
      final k = a.widget.key;
      if (k is ValueKey<String> && ellipsisAllowed.contains(k.value)) {
        allowed = true;
        return false;
      }
      return true;
    });
    if (!allowed) out.add('"${render.text.toPlainText()}"');
  }
  return out;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final problems = <String>[];

  Future<void> shot(WidgetTester t, String name) async {
    await wait(t, 600);
    for (final e in ellipsized()) {
      problems.add('$name: $e ellipsized');
    }
    await binding.takeScreenshot('$fontTag-$name');
  }

  Future<void> back(WidgetTester t) async {
    await t.binding.handlePopRoute();
    await wait(t, 700);
  }

  /// Shoots a scrollable screen at the top and, if it scrolls, the bottom.
  Future<void> shootScrolled(WidgetTester t, String name) async {
    await shot(t, name);
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    final state = t.state<ScrollableState>(scrollables.first);
    if (state.position.maxScrollExtent <= 0) return;
    state.position.jumpTo(state.position.maxScrollExtent);
    await shot(t, '$name-end');
  }

  testWidgets('layout sweep, font $fontTag', (t) async {
    await launch(t);
    await binding.convertFlutterSurfaceToImage();
    await wait(t, 300);
    await configure(t);

    for (final large in [false, true]) {
      final tag = large ? 'large' : 'regular';
      await tapKey(t, 'menu-settings');
      await setSetting(t, 'largeCards', large);
      await setSetting(t, 'winnableOnly', false);
      await shootScrolled(t, '$tag-settings');
      await back(t);

      await shot(t, '$tag-menu');
      if (!large) {
        await tapKey(t, 'menu-stats');
        await shootScrolled(t, 'stats');
        await back(t);
        await tapKey(t, 'menu-howto');
        await shootScrolled(t, 'how-to-play');
        await back(t);
        await tapKey(t, 'menu-about-app');
        await shootScrolled(t, 'about-app');
        await back(t);
        await tapKey(t, 'menu-about-studio');
        await shootScrolled(t, 'about-studio');
        await back(t);
      }

      await tapKey(t, 'menu-klondike');
      await tapKey(t, 'ksetup-deal-random');
      await typeDealNumber(t, DealNumber(1000));
      await shootScrolled(t, '$tag-new-klondike');
      await tapKey(t, 'ksetup-deal');
      await waitFor(t, find.byKey(const Key('board-title')), seconds: 60);
      await shot(t, '$tag-klondike-board');
      await tapKey(t, 'pause-pill');
      await waitFor(t, find.byKey(const Key('pause-card')));
      await shot(t, '$tag-pause');
      await tapKey(t, 'pause-menu');
      await waitFor(t, find.byKey(const Key('menu-resume')));

      await tapKey(t, 'menu-spider');
      await typeDealNumber(t, DealNumber(1000));
      await shootScrolled(t, '$tag-new-spider');
      await tapKey(t, 'ssetup-deal');
      await waitFor(t, find.byKey(const Key('board-title')), seconds: 60);
      await shot(t, '$tag-spider-board');
      await tapKey(t, 'pause-pill');
      await tapKey(t, 'pause-menu');
      await waitFor(t, find.byKey(const Key('menu-resume')));
    }

    // The loading screen: Winnable deals only with a random deal.
    await tapKey(t, 'menu-settings');
    await setSetting(t, 'winnableOnly', true);
    await back(t);
    await tapKey(t, 'menu-klondike');
    await tapKey(t, 'ksetup-deal-winnable');
    await tapKey(t, 'ksetup-deal');
    if (find.byKey(const Key('loading-count')).evaluate().isNotEmpty) {
      await shot(t, 'loading');
    } else {
      problems.add('loading: the search finished before a screenshot');
    }
    await waitFor(t, find.byKey(const Key('board-title')), seconds: 90);
    await tapKey(t, 'pause-pill');
    await tapKey(t, 'pause-menu');
    await waitFor(t, find.byKey(const Key('menu-resume')));
    await tapKey(t, 'menu-settings');
    await setSetting(t, 'winnableOnly', false);
    await back(t);

    // The win card, reached the way a player reaches it.
    var n = 1000;
    late List<Move> line;
    while (true) {
      if (solve(KlondikeGame.deal(DealNumber(n), klondike)) case Solved(
        :final moves,
      )) {
        line = moves;
        break;
      }
      n++;
    }
    await tapKey(t, 'menu-klondike');
    await tapKey(t, 'ksetup-draw-one');
    await tapKey(t, 'ksetup-timed-off');
    await tapKey(t, 'ksetup-deal-random');
    await typeDealNumber(t, DealNumber(n));
    await tapKey(t, 'ksetup-deal');
    await waitFor(t, find.byKey(const Key('board-title')), seconds: 60);
    final c = scope(t).controller;
    for (final m in line) {
      if (c.canFinish) break;
      await playMove(t, m);
    }
    await tapKey(t, 'tool-finish');
    await waitFor(t, find.byKey(const Key('win-card')), seconds: 60);
    await shot(t, 'win');

    expect(
      problems,
      isEmpty,
      reason: 'layout: ${problems.length} problem(s):\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
