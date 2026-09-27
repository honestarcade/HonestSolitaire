/// The Klondike / Spider tabs shared by How to play and Statistics.
library;

import 'package:flutter/material.dart' hide Card;

import '../a11y/tap_target.dart';
import '../game/game_event.dart';
import '../theme/palette.dart';

class GameTabs extends StatelessWidget {
  const GameTabs({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.scale = 1,
  });

  final GameType selected;
  final ValueChanged<GameType> onChanged;
  final String keyPrefix;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.all(4 * s),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(12 * s),
      ),
      child: Row(
        children: [
          for (final type in GameType.values) ...[
            if (type != GameType.values.first) SizedBox(width: 7 * s),
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == type,
                inMutuallyExclusiveGroup: true,
                label: type == GameType.klondike ? 'Klondike' : 'Spider',
                onTap: () => onChanged(type),
                excludeSemantics: true,
                child: GestureDetector(
                  key: Key('$keyPrefix-tab-${type.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(type),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: kMinTapTarget),
                    padding: EdgeInsets.all(10 * s),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == type
                          ? Palette.teal
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9 * s),
                    ),
                    child: Text(
                      type == GameType.klondike ? 'Klondike' : 'Spider',
                      style: TextStyle(
                        fontSize: 12.5 * s,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: selected == type ? Palette.ink : Palette.readout,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
