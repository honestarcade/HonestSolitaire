import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';
import 'package:honest_solitaire/ui/screens/menu_screen.dart';

void main() {
  testWidgets(
    'the app opens on the menu; Klondike → Deal is draw 3, standard, timed',
    (tester) async {
      await tester.pumpWidget(
        HonestSolitaireApp(
          showSplash: false,
          dealNumberSource: () => DealNumber(4242),
        ),
      );
      await tester.pump();
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(find.text('New game'), findsOneWidget);
      expect(find.byType(BoardView), findsNothing);
      await tester.tap(find.byKey(const Key('menu-klondike')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const Key('ksetup-deal')));
      await tester.tap(find.byKey(const Key('ksetup-deal')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BoardView), findsOneWidget);
      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byType(ToolRow), findsOneWidget);
      final scope = tester.widget<GameScope>(find.byType(GameScope));
      final game = scope.controller.game as KlondikeGame;
      expect(
        game.dealNumber.value,
        4242,
        reason: 'the first number the source gives',
      );
      expect(game.options.draw, DrawMode.three);
      expect(game.options.scoring, ScoringMode.standard);
      expect(game.options.timed, isTrue);
      expect(game.options.autoFlip, isTrue);
      expect(game.moves, 0);
      expect(find.text('Klondike · draw 3'), findsOneWidget);
      expect(
        find.text('BY HONEST ARCADE'),
        findsNothing,
        reason: 'the placeholder is gone',
      );
    },
  );
}
