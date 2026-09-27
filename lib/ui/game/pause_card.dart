/// The pause card (#80, completed by #93): over the dimmed board, the
/// game's mode line with the deal number, then Resume, Restart this deal,
/// New deal, Rules and Settings side by side, and Main menu.
library;

import 'package:flutter/material.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../app.dart';
import '../format.dart';
import '../navigation.dart';
import '../screens/how_to_play_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/palette.dart';
import 'game_controller.dart';
import 'game_event.dart';

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
  const PauseCard({
    super.key,
    required this.controller,
    required this.scale,
    this.vScale = 1,
  });

  final GameController controller;
  final double scale;

  /// Tightens the vertical spacing on short phones (#93).
  final double vScale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final v = vScale;
    final game = controller.game;
    final type = GameType.of(game);
    final scope = GameScope.maybeOf(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Paused',
      child: Container(
        key: const Key('pause-card'),
        padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 22 * s * v),
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
            SizedBox(height: 8 * s * v),
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
            SizedBox(height: 18 * s * v),
            CardButton.primary(
              'Resume',
              key: const Key('pause-resume'),
              onPressed: controller.resume,
              scale: s,
            ),
            SizedBox(height: 9 * s * v),
            CardButton.secondary(
              'Restart this deal',
              key: const Key('pause-restart'),
              onPressed: controller.restart,
              scale: s,
            ),
            SizedBox(height: 9 * s * v),
            CardButton.secondary(
              'New deal',
              key: const Key('pause-new'),
              // Without a scope (board-only tests) the deal is direct.
              onPressed: scope == null
                  ? controller.newDeal
                  : () => openSetup(context, type),
              scale: s,
            ),
            SizedBox(height: 9 * s * v),
            Row(
              children: [
                Expanded(
                  child: CardButton.secondary(
                    'Rules',
                    key: const Key('pause-rules'),
                    onPressed: () =>
                        openScreen(context, HowToPlayScreen(game: type)),
                    scale: s,
                  ),
                ),
                SizedBox(width: 9 * s),
                Expanded(
                  child: CardButton.secondary(
                    'Settings',
                    key: const Key('pause-settings'),
                    onPressed: () =>
                        openScreen(context, const SettingsScreen()),
                    scale: s,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4 * s * v),
            CardButton.quiet(
              'Main menu',
              key: const Key('pause-menu'),
              onPressed: () => goToMenu(context),
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
