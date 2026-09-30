import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/ui/screens/new_klondike_screen.dart';
import 'package:honest_solitaire/ui/screens/new_spider_screen.dart';

import 'setup_helpers.dart';

/// A number keyboard's height in dp, near the emulator's on a 568 dp screen.
const keyboard = 250.0;

void main() {
  for (final (name, screen) in [
    ('New Klondike', const NewKlondikeScreen() as Widget),
    ('New Spider', const NewSpiderScreen()),
  ]) {
    for (final size in [const Size(320, 568), const Size(384, 824)]) {
      testWidgets(
        '$name at ${size.width.toInt()} dp: the focused deal number field sits above the keyboard (#165)',
        (tester) async {
          await openScreen(tester, screen);
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          await tester.pumpAndSettle();
          final field = find.byKey(const Key('deal-number-field'));
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(of: field, matching: find.byType(EditableText)),
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
          await tester.pumpAndSettle();
          final rect = tester.getRect(field);
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - keyboard),
            reason: 'the field is under the keyboard on $name',
          );
          expect(
            rect.top,
            greaterThanOrEqualTo(0),
            reason: 'the field left the top',
          );
          // An invalid number raises the error under the field; it shows too.
          await tester.enterText(
            find.descendant(of: field, matching: find.byType(EditableText)),
            '0',
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const Key('deal-number-error'))).bottom,
            lessThanOrEqualTo(size.height - keyboard),
            reason: 'the deal number error is under the keyboard on $name',
          );
          tester.view.resetViewInsets();
        },
      );
    }
  }
}
