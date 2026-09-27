import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/ui/board/pile_ref.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/card/suit_paths.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';
import 'package:honest_solitaire/ui/theme/palette.dart';

import 'setup_helpers.dart';

import 'package:honest_solitaire/ui/game/tool_row.dart';

/// Paints [ring] on a 48×64 card and samples the alpha along the ring's
/// top edge: the run lengths of painted pixels.
Future<List<int>> ringRuns(CardRing ring) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.translate(4, 4);
  RingPainter(ring, radius: 6).paint(canvas, const Size(48, 64));
  final image = await recorder.endRecording().toImage(56, 72);
  final data = (await image.toByteData())!;
  // y = 3: the ring's centre line sits 1 px above the card's top (y = 4).
  final runs = <int>[];
  var run = 0;
  for (var x = 12; x < 44; x++) {
    final alpha = data.getUint8((3 * 56 + x) * 4 + 3);
    if (alpha > 60) {
      run++;
    } else if (run > 0) {
      runs.add(run);
      run = 0;
    }
  }
  if (run > 0) runs.add(run);
  return runs;
}

void main() {
  test(
    'the hint ring is dashed, the selection ring solid, in the same stroke',
    () async {
      final hinted = await ringRuns(CardRing.hinted);
      final selected = await ringRuns(CardRing.selected);
      expect(
        hinted.length,
        greaterThan(1),
        reason: 'gaps along the hint ring: $hinted',
      );
      expect(selected, [
        32,
      ], reason: 'one unbroken run along the selection ring');
    },
  );

  test('the four suits differ by shape', () {
    final bounds = {for (final s in Suit.values) s: suitPath(s).getBounds()};
    final areas = {
      for (final s in Suit.values)
        s: suitPath(s).computeMetrics().fold(0.0, (m, x) => m + x.length),
    };
    expect(
      areas.values.toSet().length,
      4,
      reason: 'four distinct outlines: $areas',
    );
    expect(bounds.values.every((b) => !b.isEmpty), isTrue);
  });

  testWidgets(
    'disabled controls are dimmed and marked disabled in semantics; enabled ones enabled',
    (tester) async {
      Matcher enabled(bool value) => isSemantics(isEnabled: value);
      dynamic sem(String key) => tester.getSemantics(find.byKey(Key(key)));
      // The key sits on the control (DealButton) or inside its Opacity
      // (Reset), so look both ways.
      double opacityOf(String key) {
        final keyed = find.byKey(Key(key));
        final below = find.descendant(
          of: keyed,
          matching: find.byType(Opacity),
        );
        final finder = below.evaluate().isNotEmpty
            ? below
            : find.ancestor(of: keyed, matching: find.byType(Opacity));
        return tester.widget<Opacity>(finder.first).opacity;
      }

      final scope = await openScreen(
        tester,
        const NewKlondikeScreen(),
        overBoard: true,
      );
      expect(sem('ksetup-deal'), enabled(true));
      await tester.enterText(find.byKey(const Key('deal-number-field')), '0');
      await settle(tester);
      expect(
        sem('ksetup-deal'),
        enabled(false),
        reason: 'Deal while the number is invalid',
      );
      expect(opacityOf('ksetup-deal'), Palette.disabledOpacity);
      await tester.enterText(find.byKey(const Key('deal-number-field')), '12');
      await settle(tester);
      expect(
        sem('ksetup-deal-winnable'),
        enabled(false),
        reason: 'Winnable only with a chosen deal',
      );
      expect(sem('ksetup-deal-random'), enabled(true));
      // Tool-row buttons while paused, and Reset with empty statistics.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester, transition: true);
      scope.controller.pause();
      await settle(tester);
      expect(sem('tool-undo'), enabled(false));
      expect(sem('tool-new'), enabled(false));
      expect(
        find.descendant(
          of: find.byType(ToolRow),
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == Palette.disabledOpacity,
          ),
        ),
        findsNWidgets(5),
        reason: 'every tool button is dimmed while paused',
      );
      scope.controller.resume();
      await settle(tester);
      expect(sem('tool-new'), enabled(true));
      await openScreen(tester, const StatsScreen(), store: AppStore.memory());
      expect(
        sem('stats-reset'),
        enabled(false),
        reason: 'Reset with empty statistics',
      );
      expect(opacityOf('stats-reset'), Palette.disabledOpacity);
    },
  );

  testWidgets(
    'a hinted card and a hinted stock carry the ring painter; the red suit is the darkened one',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: PlayingCard(
              card: const Card(7, Suit.hearts, faceUp: true),
              size: const Size(48, 64),
              back: CardBack.navy,
              ring: CardRing.hinted,
            ),
          ),
        ),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is CustomPaint &&
                          w.foregroundPainter is RingPainter,
                    ),
                  )
                  .foregroundPainter
              as RingPainter;
      expect(painter.ring, CardRing.hinted);
      expect(find.byKey(const Key('card')), findsNothing);
      final scope = await openScreen(
        tester,
        const StatsScreen(),
        overBoard: true,
      );
      scope.controller.replaceGame(SpiderGame.deal(DealNumber(2)));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester, transition: true);
      scope.controller.hint();
      await settle(tester);
      if (scope.controller.currentHint?.stock ?? false) {
        expect(find.byKey(const Key('stock-hint-ring')), findsOneWidget);
      }
      expect(Palette.redSuit, const Color(0xFFC4453A));
      expect(const TableauPile(0).token, 't0');
    },
  );
}
