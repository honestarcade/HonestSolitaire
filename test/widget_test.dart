import 'package:flutter_test/flutter_test.dart';

import 'package:honest_solitaire/main.dart';

void main() {
  testWidgets('the app starts on the branded placeholder screen', (
    tester,
  ) async {
    await tester.pumpWidget(const HonestSolitaireApp());

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.text('BY HONEST ARCADE'), findsOneWidget);
  });
}
