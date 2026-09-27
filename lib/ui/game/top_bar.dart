/// The top bar (#78): the pause pill with the game's title, and the time,
/// moves and score readouts, each following its setting.
library;

import 'package:flutter/material.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../format.dart';
import '../motion.dart';
import '../theme/palette.dart';
import '../widgets/appear.dart';
import 'game_controller.dart';
import 'notice_banner.dart';
import '../fonts.dart';
import '../icons/glyphs.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.controller, required this.scale});

  final GameController controller;

  /// Board width over the design's 390.
  final double scale;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller.displayGame,
      controller.displayOptions,
      controller,
    ]),
    builder: (context, _) {
      final game = controller.displayGame.value;
      final options = controller.display;
      final readouts = <Widget>[];
      final notice = controller.currentHint?.noMoves ?? false;
      if (options.showTimer && isTimed(game)) {
        readouts.add(
          _Readout(
            key: const Key('readout-time'),
            label: '',
            value: formatClock(game.elapsed),
            minValue: '0:00',
            scale: scale,
            semantics: spokenTime(game.elapsed),
          ),
        );
      }
      if (options.showMovesAndScore) {
        readouts.add(
          _Readout(
            key: const Key('readout-moves'),
            label: 'MOV',
            value: formatCount(game.moves),
            minValue: '0',
            scale: scale,
            semantics: spokenMoves(game.moves),
          ),
        );
        final score = formatScore(game);
        if (score != null) {
          readouts.add(
            _Readout(
              key: const Key('readout-score'),
              label: scoreLabel(game)!,
              value: score,
              minValue: '0',
              scale: scale,
              semantics: spokenScore(game)!,
            ),
          );
        }
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale),
        child: Row(
          children: [
            // The pill takes what the readouts leave and ellipsizes; it
            // never pushes them off a narrow phone.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PausePill(
                  controller: controller,
                  game: game,
                  scale: scale,
                ),
              ),
            ),
            if (notice) ...[
              SizedBox(width: 6 * scale),
              Flexible(
                flex: 3,
                child: Appear(
                  motion: AppMotion.of(context, controller.settings),
                  duration: bannerFade,
                  child: NoticeBanner(
                    key: const Key('no-moves-banner'),
                    message: 'No moves left',
                    scale: scale,
                    actions: [
                      NoticeAction(
                        'Undo',
                        controller.undo,
                        enabled: controller.canUndo,
                      ),
                      NoticeAction('New deal', controller.newDeal),
                    ],
                  ),
                ),
              ),
            ] else
              for (final r in readouts) ...[SizedBox(width: 6 * scale), r],
          ],
        ),
      );
    },
  );
}

class _PausePill extends StatelessWidget {
  const _PausePill({
    required this.controller,
    required this.game,
    required this.scale,
  });

  final GameController controller;
  final Game game;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final enabled = !controller.isPaused && !game.isWon;
    final title = gameTitle(game);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Pause, ${title.replaceAll(' · ', ' ')}',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : Palette.disabledOpacity,
        child: GestureDetector(
          key: const Key('pause-pill'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? controller.pause : null,
          child: Container(
            constraints: BoxConstraints(minHeight: 44 * scale, minWidth: 48),
            padding: EdgeInsets.symmetric(horizontal: 11 * scale),
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 11 * scale,
                vertical: 8 * scale,
              ),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                border: Border.all(color: const Color(0x24FFFFFF)),
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlyphIcon(Glyph.pause, size: 10 * scale, color: Colors.white),
                  SizedBox(width: 7 * scale),
                  Flexible(
                    child: Text(
                      title,
                      key: const Key('board-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Large text (#106): up to 1.3× within the bar's
                      // height; the pill ellipsizes rather than clipping.
                      textScaler: _barScaler(context),
                      style: TextStyle(
                        fontSize: 11.5 * scale,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    super.key,
    required this.label,
    required this.value,
    required this.minValue,
    required this.scale,
    required this.semantics,
  });

  final String label;
  final String value;
  final String minValue;
  final double scale;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kFontMono,
      fontSize: 10 * scale,
      fontWeight: FontWeight.w500,
      color: Palette.readout,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final text = label.isEmpty ? value : '$label $value';
    final minText = label.isEmpty ? minValue : '$label $minValue';
    final scaler = _barScaler(context);
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 9 * scale,
          vertical: 7 * scale,
        ),
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(9 * scale),
        ),
        // The readout keeps the bar's height: scaled text is fitted back
        // down when the row would clip it (#106).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Opacity(
                opacity: 0,
                child: Text(minText, style: style, textScaler: scaler),
              ),
              Text(
                text,
                key: const Key('value'),
                style: style,
                textScaler: scaler,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone's text scale for the bars (#106): the app's clamp already caps
/// it at 1.3×; a bar's text is then fitted down where the row is tight.
TextScaler _barScaler(BuildContext context) => MediaQuery.textScalerOf(context);
