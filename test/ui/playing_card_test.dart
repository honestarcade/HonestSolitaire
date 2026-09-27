import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/ui/brand/honest_mark.dart';
import 'package:honest_solitaire/ui/card/card_back_painter.dart';
import 'package:honest_solitaire/ui/card/card_style.dart';
import 'package:honest_solitaire/ui/card/playing_card.dart';
import 'package:honest_solitaire/ui/card/suit_paths.dart';
import 'package:honest_solitaire/ui/theme/palette.dart';

Widget host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

const klondike = Size(48, 72);
const spider = Size(34, 52);

void main() {
  testWidgets('a face-up K♠ and 7♥ show their rank in the right colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            PlayingCard(
              card: Card(13, Suit.spades, faceUp: true),
              size: klondike,
              back: CardBack.navy,
            ),
            PlayingCard(
              card: Card(7, Suit.hearts, faceUp: true),
              size: klondike,
              back: CardBack.navy,
            ),
          ],
        ),
      ),
    );
    final king = tester.widget<Text>(find.text('K'));
    expect(king.style!.color, Palette.blackSuit);
    expect(king.style!.fontWeight, FontWeight.w700);
    expect(king.style!.fontSize, 22, reason: 'round(48 × 0.46)');
    final seven = tester.widget<Text>(find.text('7'));
    expect(seven.style!.color, Palette.redSuit);
    // Suits are painted paths, never glyphs.
    expect(find.text('♠'), findsNothing);
    expect(find.text('♥'), findsNothing);
    expect(find.byType(CustomPaint), findsNWidgets(2));
    expect(find.bySemanticsLabel('King of spades'), findsOneWidget);
    expect(find.bySemanticsLabel('Seven of hearts'), findsOneWidget);
  });

  testWidgets('a face-down card exposes no rank or suit', (tester) async {
    await tester.pumpWidget(
      host(
        const PlayingCard(
          card: Card(12, Suit.diamonds),
          size: klondike,
          back: CardBack.teal,
        ),
      ),
    );
    expect(find.text('Q'), findsNothing);
    expect(find.byKey(const Key('rank')), findsNothing);
    expect(find.bySemanticsLabel('face-down card'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('diamonds')), findsNothing);
    final paint = tester.widget<CustomPaint>(find.byType(CustomPaint));
    expect(paint.painter, isA<CardBackPainter>());
    expect((paint.painter as CardBackPainter).back, CardBack.teal);
  });

  test('every back style paints into a picture, and repaints only on a style change', () {
    for (final back in CardBack.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CardBackPainter(back, radius: 6, scale: 1).paint(canvas, klondike);
      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0), reason: back.name);
      picture.dispose();
    }
    const navy = CardBackPainter(CardBack.navy, radius: 6, scale: 1);
    expect(
      navy.shouldRepaint(
        const CardBackPainter(CardBack.navy, radius: 6, scale: 1),
      ),
      isFalse,
    );
    expect(
      navy.shouldRepaint(
        const CardBackPainter(CardBack.violet, radius: 6, scale: 1),
      ),
      isTrue,
    );
    expect(
      navy.shouldRepaint(
        const CardBackPainter(CardBack.navy, radius: 5, scale: 1),
      ),
      isTrue,
    );
    final recorder = ui.PictureRecorder();
    const HonestMarkPainter().paint(Canvas(recorder), const Size(40, 40));
    expect(recorder.endRecording().approximateBytesUsed, greaterThan(0));
    expect(HonestMarkPainter.strokes, hasLength(4));
    expect(HonestMarkPainter.strokes.map((s) => s.$1), [
      Palette.teal,
      Palette.violet,
      Palette.blue,
      Palette.markDeepBlue,
    ]);
  });

  testWidgets(
    'ring states paint a ring (#102); none keeps a hairline edge and the drop shadow',
    (tester) async {
      Future<(RingPainter?, List<BoxShadow>)> paintFor(
        CardRing ring, {
        bool faceUp = true,
      }) async {
        await tester.pumpWidget(
          host(
            PlayingCard(
              card: Card(5, Suit.clubs, faceUp: faceUp),
              size: klondike,
              back: CardBack.navy,
              ring: ring,
            ),
          ),
        );
        final paints = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is RingPainter,
        );
        final painter = paints.evaluate().isEmpty
            ? null
            : tester.widget<CustomPaint>(paints).foregroundPainter
                  as RingPainter?;
        final box = tester.widget<Container>(find.byType(Container));
        return (painter, (box.decoration as BoxDecoration).boxShadow!);
      }

      final (selectedRing, selected) = await paintFor(CardRing.selected);
      expect(selectedRing!.ring, CardRing.selected);
      final (hintedRing, hinted) = await paintFor(CardRing.hinted);
      expect(hintedRing!.ring, CardRing.hinted);
      final (noRing, none) = await paintFor(CardRing.none);
      expect(noRing, isNull);
      expect(none.first.color, Palette.faceEdge);
      expect(none.first.spreadRadius, 1);
      final (_, down) = await paintFor(CardRing.none, faceUp: false);
      expect(down.first.color, Palette.backEdge);
      // Every state carries the design's drop shadow last.
      for (final s in [selected, hinted, none, down]) {
        expect(s.last.color, Palette.cardShadow);
        expect(s.last.offset, const Offset(0, 2));
      }
    },
  );

  testWidgets('narrow cards use the narrow rank ratio', (tester) async {
    await tester.pumpWidget(
      host(
        const PlayingCard(
          card: Card(10, Suit.spades, faceUp: true),
          size: spider,
          back: CardBack.navy,
          narrow: true,
        ),
      ),
    );
    final ten = tester.widget<Text>(find.text('10'));
    expect(ten.style!.fontSize, 18, reason: 'round(34 × 0.52)');
    await tester.pumpWidget(
      host(
        const PlayingCard(
          card: Card(10, Suit.spades, faceUp: true),
          size: spider,
          back: CardBack.navy,
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('10')).style!.fontSize,
      16,
      reason: 'round(34 × 0.46) without the flag',
    );
  });

  testWidgets(
    'PlayingCard.back draws a back with no card, optionally without an edge',
    (tester) async {
      await tester.pumpWidget(
        host(
          const PlayingCard.back(Size(26, 36), CardBack.violet, edge: false),
        ),
      );
      expect(find.bySemanticsLabel('face-down card'), findsOneWidget);
      final box = tester.widget<Container>(find.byType(Container));
      final shadows = (box.decoration as BoxDecoration).boxShadow!;
      expect(shadows, hasLength(1), reason: 'only the drop shadow');
      expect(shadows.single.blurRadius, 4);
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(26 * 0.125),
      );
    },
  );

  testWidgets('card text ignores the system text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(
          const PlayingCard(
            card: Card(9, Suit.hearts, faceUp: true),
            size: klondike,
            back: CardBack.navy,
          ),
        ),
      ),
    );
    final size = tester.getSize(find.text('9'));
    expect(size.height, lessThan(30), reason: 'a 22 px rank did not double');
  });

  test('suit paths fill most of their box and stay inside it', () {
    for (final suit in Suit.values) {
      final bounds = suitPathAt(suit, Offset.zero, 100).getBounds();
      expect(bounds.left, greaterThanOrEqualTo(0), reason: suit.name);
      expect(bounds.top, greaterThanOrEqualTo(0), reason: suit.name);
      expect(bounds.right, lessThanOrEqualTo(100.01), reason: suit.name);
      expect(bounds.bottom, lessThanOrEqualTo(100.01), reason: suit.name);
      expect(bounds.width, greaterThan(60), reason: suit.name);
      expect(bounds.height, greaterThan(70), reason: suit.name);
    }
  });
}
