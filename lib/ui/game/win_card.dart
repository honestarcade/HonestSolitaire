/// The win card (#80): GAME COMPLETE, the game's title, and cells for time,
/// moves, score (or dollars) and the time bonus when one was earned.
library;

import 'package:flutter/material.dart';
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../format.dart';
import '../theme/palette.dart';
import 'game_controller.dart';
import 'pause_card.dart';

/// The cells the card shows, in order.
List<(String, String)> winCells(Game game) {
  final cells = <(String, String)>[];
  if (isTimed(game)) {
    cells.add(('TIME', formatClock(game.elapsed)));
  }
  cells.add(('MOVES', formatCount(game.moves)));
  switch (game) {
    case KlondikeGame k when k.scoring == ScoringMode.none:
      break;
    case KlondikeGame k when k.scoring == ScoringMode.vegas:
      cells.add(('DOLLARS', formatDollars(k.score)));
    default:
      cells.add(('SCORE', formatCount(game.score)));
  }
  if (game.timeBonus > 0) {
    cells.add(('TIME BONUS', '+${formatCount(game.timeBonus)}'));
  }
  return cells;
}

class WinCard extends StatelessWidget {
  const WinCard({super.key, required this.controller, required this.scale});

  final GameController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final game = controller.game;
    final title = switch (game) {
      KlondikeGame() => 'Foundations complete',
      SpiderGame() => 'All eight runs home',
    };
    final cells = winCells(game);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Game complete',
      child: Container(
        key: const Key('win-card'),
        padding: EdgeInsets.all(24 * s),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Palette.card, Palette.cardDeep],
          ),
          borderRadius: BorderRadius.circular(20 * s),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              offset: Offset(0, 24),
              blurRadius: 60,
            ),
          ],
          border: Border.all(color: const Color(0x4D00D6B4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'GAME COMPLETE',
              style: TextStyle(
                fontSize: 10 * s,
                fontWeight: FontWeight.w500,
                letterSpacing: 2 * s,
                color: Palette.teal,
                height: 1,
              ),
            ),
            SizedBox(height: 11 * s),
            Text(
              title,
              style: TextStyle(
                fontSize: 27 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.54 * s,
                color: Colors.white,
                height: 1,
              ),
            ),
            SizedBox(height: 18 * s),
            _Grid(cells: cells, scale: s),
            SizedBox(height: 18 * s),
            CardButton.primary(
              'New deal',
              key: const Key('win-new'),
              onPressed: controller.newDeal,
              scale: s,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two columns; an odd last cell spans both.
class _Grid extends StatelessWidget {
  const _Grid({required this.cells, required this.scale});

  final List<(String, String)> cells;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      final last = i + 1 >= cells.length;
      rows.add(
        Row(
          children: [
            Expanded(child: _Cell(cells[i], s)),
            if (!last) ...[
              SizedBox(width: 9 * s),
              Expanded(child: _Cell(cells[i + 1], s)),
            ],
          ],
        ),
      );
      if (i + 2 < cells.length) rows.add(SizedBox(height: 9 * s));
    }
    return Column(children: rows);
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.cell, this.scale);

  final (String, String) cell;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      key: Key('win-cell-${cell.$1.toLowerCase().replaceAll(' ', '-')}'),
      padding: EdgeInsets.symmetric(horizontal: 13 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(12 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cell.$1,
            style: TextStyle(
              fontSize: 9 * s,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.14 * 9 * s,
              color: Palette.mist,
              height: 1,
            ),
          ),
          SizedBox(height: 7 * s),
          Text(
            cell.$2,
            style: TextStyle(
              fontSize: 18 * s,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrim and card layer over the board.
class GameOverlays extends StatelessWidget {
  const GameOverlays({
    super.key,
    required this.controller,
    required this.scale,
  });

  final GameController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final showWin = controller.winShown;
    final showPause = controller.isPaused && !showWin;
    if (!showWin && !showPause) return const SizedBox.shrink();
    return Positioned.fill(
      child: MediaQuery.withNoTextScaling(
        child: Semantics(
          container: true,
          child: GestureDetector(
            // The scrim swallows taps and does nothing.
            key: const Key('scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              color: showWin
                  ? const Color(0xD9030E20)
                  : const Color(0xD1030E20),
              padding: EdgeInsets.all(26 * scale),
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {},
                child: showWin
                    ? WinCard(controller: controller, scale: scale)
                    : PauseCard(controller: controller, scale: scale),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
