/// The shared screen chrome (M4): the ‹ back button and the title, and the
/// scrolling scaffold every non-board screen uses.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../board/board_layout.dart';
import '../theme/palette.dart';
import '../fonts.dart';

/// Board width over the design's 390, capped like the board.
double screenScale(BuildContext context) =>
    math.min(MediaQuery.sizeOf(context).width, maxBoardWidth) / designWidth;

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.keyPrefix,
    this.kicker,
    this.kickerColor = const Color(0xFF6E93C4),
    this.scale = 1,
  });

  final String title;
  final VoidCallback onBack;
  final String keyPrefix;

  /// The mono caps line under the title ("STANDARD 52-CARD DEAL").
  final String? kicker;
  final Color kickerColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Back',
          excludeSemantics: true,
          child: GestureDetector(
            key: Key('$keyPrefix-back'),
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 34 * s,
                  height: 34 * s,
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    border: Border.all(color: const Color(0x29FFFFFF)),
                    borderRadius: BorderRadius.circular(11 * s),
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: Size(8 * s, 12 * s),
                    painter: const _Chevron(),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 6 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 19 * s,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              if (kicker != null) ...[
                SizedBox(height: 6 * s),
                Text(
                  kicker!,
                  style: TextStyle(
                    fontSize: 9.5 * s,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.16 * 9.5 * s,
                    fontFamily: kFontMono,
                    color: kickerColor,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// ‹ as a painted stroke.
class _Chevron extends CustomPainter {
  const _Chevron();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Chevron oldDelegate) => false;
}

/// A non-board screen: navy background (or a gradient), safe-area padding
/// (top + 20, bottom + 24), horizontal padding 20, the content scrolling,
/// with [pinned] sitting at the bottom when the content fits and following
/// it when it scrolls. Sizes scale by width/390, capped at 480.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.children,
    this.pinned,
    this.gap = 13,
    this.gradient,
    this.controller,
  });

  final List<Widget> children;
  final Widget? pinned;
  final double gap;
  final Gradient? gradient;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final s = screenScale(context);
    final insets = MediaQuery.viewPaddingOf(context);
    return MediaQuery.withNoTextScaling(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Palette.navy, gradient: gradient),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, maxBoardWidth);
            return SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.only(
                top: insets.top + 20 * s,
                bottom: insets.bottom + 24 * s,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    minHeight:
                        constraints.maxHeight -
                        insets.top -
                        insets.bottom -
                        44 * s,
                  ),
                  // IntrinsicHeight bounds the column to the taller of the
                  // viewport and its content, so the Spacer before the
                  // pinned part has a finite height to fill.
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) SizedBox(height: gap * s),
                            children[i],
                          ],
                          if (pinned != null) ...[
                            const Spacer(),
                            SizedBox(height: gap * s),
                            pinned!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A design panel: 14×15 padding, radius 14, white 5 %.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.scale = 1,
    this.color = const Color(0x0DFFFFFF),
    this.border,
    this.padding,
  });

  final Widget child;
  final double scale;
  final Color color;
  final Color? border;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding:
        padding ??
        EdgeInsets.symmetric(horizontal: 15 * scale, vertical: 14 * scale),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14 * scale),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: child,
  );
}

/// The mono caps section kicker ("PLAY", "BY DRAW MODE").
class Kicker extends StatelessWidget {
  const Kicker(
    this.text, {
    super.key,
    this.scale = 1,
    this.color = const Color(0xFF6E93C4),
    this.size = 9.5,
  });

  final String text;
  final double scale;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: TextStyle(
        fontFamily: kFontMono,
        fontSize: size * scale,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.16 * size * scale,
        color: color,
        height: 1,
      ),
    ),
  );
}
