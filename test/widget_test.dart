import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';
import 'package:honest_solitaire/ui/app.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/game/tool_row.dart';
import 'package:honest_solitaire/ui/game/top_bar.dart';

void main() {
  testWidgets('the app opens on a Klondike board: draw 3, standard, timed', (
    tester,
  ) async {
    await tester.pumpWidget(
      HonestSolitaireApp(
        showSplash: false,
        dealNumberSource: () => DealNumber(4242),
      ),
    );
    expect(find.byType(BoardView), findsOneWidget);
    expect(find.byType(TopBar), findsOneWidget);
    expect(find.byType(ToolRow), findsOneWidget);
    final scope = tester.widget<GameScope>(find.byType(GameScope));
    final game = scope.controller.game as KlondikeGame;
    expect(game.dealNumber.value, 4242);
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
  });
}
