import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/data/app_store.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/fonts.dart';
import 'package:honest_solitaire/ui/navigation.dart';
import 'package:honest_solitaire/ui/screens/stats_screen.dart';

import '../helpers/fonts.dart';
import 'setup_helpers.dart';

/// The family every visible text run resolves to, or null.
Set<String?> familiesOnScreen(WidgetTester tester) => {
  for (final r in tester.allRenderObjects.whereType<RenderParagraph>())
    r.text.style?.fontFamily,
};

double widthOf(String family, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontSize: 20),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'the menu, a board and Statistics render every text run in Outfit or IBM Plex Mono',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        HonestSolitaireApp(
          store: AppStore.memory(),
          showSplash: false,
          dealNumberSource: () => DealNumber(8),
        ),
      );
      await settle(tester);
      final menu = familiesOnScreen(tester);
      expect(
        menu,
        isNot(contains(null)),
        reason:
            'a text run with no family would fall back to the platform font',
      );
      expect(menu, containsAll([kFontOutfit, kFontMono]));
      expect(menu.length, 2, reason: '$menu');
      tester.state<NavigatorState>(find.byType(Navigator)).push(boardRoute());
      await settle(tester, transition: true);
      final board = familiesOnScreen(tester);
      expect(board, isNot(contains(null)));
      expect(
        board,
        containsAll([kFontOutfit, kFontMono]),
        reason: 'ranks in Outfit, readouts in Plex Mono',
      );
      expect(board.length, 2, reason: '$board');
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(MaterialPageRoute<void>(builder: (_) => const StatsScreen()));
      await settle(tester, transition: true);
      final stats = familiesOnScreen(tester);
      expect(stats, isNot(contains(null)));
      expect(stats, containsAll([kFontOutfit, kFontMono]));
      expect(stats.length, 2, reason: '$stats');
    },
  );

  testWidgets(
    'the bundled faces really load: Plex, Outfit and Ahem measure differently',
    (tester) async {
      final digits = '0123456789';
      final outfit = widthOf(kFontOutfit, digits);
      final plex = widthOf(kFontMono, digits);
      final ahem = widthOf('Ahem', digits);
      expect((outfit - plex).abs() / plex, greaterThan(0.05));
      expect((outfit - ahem).abs() / ahem, greaterThan(0.05));
      expect((plex - ahem).abs() / ahem, greaterThan(0.05));
    },
  );
}
