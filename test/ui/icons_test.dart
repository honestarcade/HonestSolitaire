import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/icons/glyphs.dart';
import 'package:honest_solitaire/ui/navigation.dart' show boardRoute;
import 'package:honest_solitaire/ui/screens/about_app_screen.dart';
import 'package:honest_solitaire/ui/widgets/screen_header.dart';

import 'setup_helpers.dart';

void main() {
  test('every glyph paints a non-empty path inside the 24 box at 24 px', () {
    for (final g in Glyph.values) {
      final bounds = glyphPath(g, 24).getBounds();
      expect(bounds.isEmpty, isFalse, reason: g.name);
      expect(bounds.left, greaterThanOrEqualTo(0), reason: g.name);
      expect(bounds.top, greaterThanOrEqualTo(0), reason: g.name);
      expect(bounds.right, lessThanOrEqualTo(24), reason: g.name);
      expect(bounds.bottom, lessThanOrEqualTo(24), reason: g.name);
      expect(
        glyphPath(g, 48).getBounds().width,
        closeTo(bounds.width * 2, 0.01),
        reason: '${g.name} scales',
      );
    }
    expect(
      Glyph.values.where((g) => g.filled),
      containsAll([Glyph.hint, Glyph.newGame, Glyph.deal, Glyph.pause]),
    );
  });

  testWidgets('a standalone icon carries its label; a decorative one none', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            GlyphIcon(Glyph.back, size: 16, semanticLabel: 'Back'),
            GlyphIcon(Glyph.check, size: 10),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.byType(GlyphIcon), findsNWidgets(2));
    expect(tester.getSemantics(find.byType(GlyphIcon).last).label, '');
  });

  testWidgets(
    'the tool row and the header render icons, not text glyphs; a link says it opens in browser',
    (tester) async {
      final scope = await openScreen(tester, const AboutAppScreen());
      expect(find.byType(GlyphIcon), findsWidgets);
      expect(find.text('‹'), findsNothing);
      expect(find.text('✓'), findsNothing);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(
        find.bySemanticsLabel('HONEST ARCADE, opens in browser'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('SOURCE ON GITHUB, opens in browser')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ScreenHeader),
          matching: find.byType(GlyphIcon),
        ),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator)).push(boardRoute());
      await settle(tester, transition: true);
      final toolIcons = find.descendant(
        of: find.byType(ToolRow),
        matching: find.byType(GlyphIcon),
      );
      expect(toolIcons, findsNWidgets(5));
      for (final g in ['↺', '✦', '⇈', '⟳', '✚']) {
        expect(find.text(g), findsNothing, reason: g);
      }
      expect(tester.widgetList<GlyphIcon>(toolIcons).map((i) => i.glyph), [
        Glyph.undo,
        Glyph.hint,
        Glyph.finish,
        Glyph.restart,
        Glyph.newGame,
      ]);
      expect(scope.controller.game, isNotNull);
    },
  );

  testWidgets(
    'a menu opened plain shows the chevron and, with a notice, the dismiss icon',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        HonestSolitaireApp(
          store: AppStore.memory(),
          showSplash: false,
          dealNumberSource: () => DealNumber(3),
        ),
      );
      await settle(tester);
      expect(find.text('›'), findsNothing);
      expect(
        tester
            .widgetList<GlyphIcon>(find.byType(GlyphIcon))
            .map((i) => i.glyph),
        contains(Glyph.chevron),
      );
      final scope = tester.widget<GameScope>(find.byType(GameScope));
      await scope.store.quarantine(StoreDoc.stats, 'test');
      await settle(tester);
      expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
      expect(find.text('✕'), findsNothing);
    },
  );
}
