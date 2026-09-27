/// The pause card (#80): over the dimmed board, the game's mode line with
/// the deal number, then Resume, Restart this deal, New deal and — until
/// M4's menu — a switch to the other game.
library;

import 'package:flutter/material.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../format.dart';
import '../theme/palette.dart';
import 'game_controller.dart';

/// "KLONDIKE · DRAW 3 · VEGAS · 2:14 · DEAL #48213".
String pauseMeta(Game game) {
  final parts = <String>[];
  switch (game) {
    case KlondikeGame k:
      parts.add('KLONDIKE');
      parts.add('DRAW ${k.options.draw.count}');
      if (k.scoring == ScoringMode.vegas) parts.add('VEGAS');
      if (k.scoring == ScoringMode.none) parts.add('NO SCORE');
    case SpiderGame s:
      parts.add('SPIDER');
      parts.add(
        '${s.options.suits.count} SUIT${s.options.suits.count == 1 ? '' : 'S'}',
      );
  }
  if (isTimed(game)) parts.add(formatClock(game.elapsed));
  parts.add('DEAL #${game.dealNumber.value}');
  return parts.join(' · ');
}

class PauseCard extends StatelessWidget {
  const PauseCard({super.key, required this.controller, required this.scale});

  final GameController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final game = controller.game;
    final otherLabel = switch (game) {
      KlondikeGame() => 'Switch to Spider (2 suits)',
      SpiderGame() => 'Switch to Klondike',
    };
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Paused',
      child: Container(
        key: const Key('pause-card'),
        padding: EdgeInsets.all(22 * s),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(20 * s),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              offset: Offset(0, 24),
              blurRadius: 60,
            ),
          ],
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paused',
              style: TextStyle(
                fontSize: 19 * s,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
            SizedBox(height: 8 * s),
            Text(
              pauseMeta(game),
              key: const Key('pause-meta'),
              style: TextStyle(
                fontSize: 10 * s,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.14 * 10 * s,
                color: Palette.mist,
                height: 1,
              ),
            ),
            SizedBox(height: 18 * s),
            CardButton.primary(
              'Resume',
              key: const Key('pause-resume'),
              onPressed: controller.resume,
              scale: s,
            ),
            SizedBox(height: 9 * s),
            CardButton.secondary(
              'Restart this deal',
              key: const Key('pause-restart'),
              onPressed: controller.restart,
              scale: s,
            ),
            SizedBox(height: 9 * s),
            CardButton.secondary(
              'New deal',
              key: const Key('pause-new'),
              onPressed: controller.newDeal,
              scale: s,
            ),
            SizedBox(height: 9 * s),
            CardButton.secondary(
              otherLabel,
              key: const Key('pause-switch'),
              onPressed: controller.switchGame,
              scale: s,
            ),
          ],
        ),
      ),
    );
  }
}

/// The cards' buttons: teal primary, outlined secondary, quiet tertiary.
class CardButton extends StatelessWidget {
  const CardButton.primary(
    this.label, {
    super.key,
    required this.onPressed,
    required this.scale,
  }) : _style = _Style.primary;

  const CardButton.secondary(
    this.label, {
    super.key,
    required this.onPressed,
    required this.scale,
  }) : _style = _Style.secondary;

  const CardButton.quiet(
    this.label, {
    super.key,
    required this.onPressed,
    required this.scale,
  }) : _style = _Style.quiet;

  final String label;
  final VoidCallback onPressed;
  final double scale;
  final _Style _style;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final (bg, fg, border, pad, size, weight) = switch (_style) {
      _Style.primary => (
        Palette.teal,
        Palette.ink,
        null,
        15.0,
        15.0,
        FontWeight.w600,
      ),
      _Style.secondary => (
        const Color(0x0DFFFFFF),
        Colors.white,
        const Color(0x2EFFFFFF),
        14.0,
        14.0,
        FontWeight.w500,
      ),
      _Style.quiet => (
        Colors.transparent,
        Palette.mist,
        null,
        13.0,
        13.0,
        FontWeight.w500,
      ),
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(vertical: pad * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(13 * s),
            border: border == null ? null : Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: size * s,
              fontWeight: weight,
              color: fg,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

enum _Style { primary, secondary, quiet }
