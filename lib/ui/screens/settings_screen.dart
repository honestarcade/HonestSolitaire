/// The Settings screen (#86): the card back, every Play, Display and Sound
/// toggle, applied the moment they change and remembered across restarts.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/game.dart';

import '../../app_version.dart';
import '../app.dart';
import '../card/card_style.dart';
import '../card/playing_card.dart';
import '../settings/display_options.dart';
import '../settings/play_settings.dart';
import '../theme/palette.dart';
import '../widgets/screen_header.dart';

/// One row of the design's list.
class SettingRow {
  const SettingRow(
    this.field,
    this.label,
    this.description, {
    this.nextDeal = false,
    this.klondikeOnly = false,
  });

  final String field;
  final String label;
  final String description;

  /// Takes effect at the next deal, so a live game shows a note.
  final bool nextDeal;
  final bool klondikeOnly;
}

/// The design's rows, corrected to what the app does (owner, gate list).
const playRows = [
  SettingRow(
    'oneTap',
    'One-tap move',
    'Tapping a card sends it to the best legal spot.',
  ),
  SettingRow(
    'autoFinish',
    'Auto-finish',
    'Sweep the rest to the foundations once the board is solved.',
  ),
  SettingRow(
    'autoFlip',
    'Auto-flip cards',
    'Turn a face-down card the moment it is uncovered.',
    nextDeal: true,
  ),
  SettingRow(
    'unlimitedUndo',
    'Unlimited undo',
    'Undo any number of moves, including drawing from the stock. Off: only your last move, and never a draw.',
  ),
  SettingRow(
    'winnableOnly',
    'Winnable deals only',
    'Deal from solvable shuffles — Klondike only. Off is a true random deal.',
    nextDeal: true,
    klondikeOnly: true,
  ),
];
const displayRows = [
  SettingRow(
    'leftHanded',
    'Left-handed layout',
    'Mirror the stock, waste, foundations and tool row to the other side.',
  ),
  SettingRow(
    'largeCards',
    'Large cards',
    'Fewer pixels of felt, bigger ranks and suits.',
  ),
  SettingRow('showTimer', 'Show timer', 'Elapsed time in the top bar.'),
  SettingRow(
    'showMovesAndScore',
    'Show moves and score',
    'Move count and running score in the top bar.',
  ),
  SettingRow(
    'cardAnimations',
    'Card animations',
    'Slides, flips and the win cascade.',
  ),
];
const soundRows = [
  SettingRow(
    'sound',
    'Sound effects',
    'Deals, flips, snaps and the completed-suit chime.',
  ),
  SettingRow('music', 'Background music', 'Quiet loop while you play.'),
  SettingRow(
    'haptics',
    'Haptics',
    'A short tick on an illegal move or a completed run.',
  ),
];

const storedNote =
    'Games, statistics and settings are kept on your phone, and the app never uploads them. '
    'If Android backup is on, Android may include them in your Google account backup — your '
    'setting, not ours. No account, no sync, nothing to delete on a server.';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    return ScreenScaffold(
      gap: 12,
      children: [
        ScreenHeader(
          title: 'Settings',
          onBack: () => Navigator.of(context).maybePop(),
          keyPrefix: 'settings',
          scale: s,
        ),
        ValueListenableBuilder(
          valueListenable: scope.displayOptions,
          builder: (context, display, _) => _CardBackPanel(
            display: display,
            scale: s,
            onPick: (back) =>
                scope.displayOptions.value = display.copyWith(cardBack: back),
          ),
        ),
        _Group(title: 'PLAY', rows: playRows, scale: s),
        _Group(title: 'DISPLAY', rows: displayRows, scale: s),
        _Group(title: 'SOUND', rows: soundRows, scale: s),
        Panel(
          scale: s,
          color: const Color(0x0AFFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('STORED ON DEVICE ONLY', scale: s, size: 9),
              SizedBox(height: 9 * s),
              Text(
                storedNote,
                key: const Key('settings-stored-note'),
                style: TextStyle(
                  fontSize: 11 * s,
                  height: 1.5,
                  color: const Color(0xFF87A9D0),
                ),
              ),
            ],
          ),
        ),
        Text(
          versionLine,
          key: const Key('settings-version'),
          style: TextStyle(
            fontSize: 9.5 * s,
            height: 1.6,
            letterSpacing: 0.14 * 9.5 * s,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4E739F),
          ),
        ),
      ],
    );
  }
}

class _CardBackPanel extends StatelessWidget {
  const _CardBackPanel({
    required this.display,
    required this.scale,
    required this.onPick,
  });

  final DisplayOptions display;
  final double scale;
  final ValueChanged<CardBack> onPick;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Panel(
      scale: s,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card back',
            style: TextStyle(
              fontSize: 13 * s,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Every back carries the Honest Arcade mark.',
            style: TextStyle(
              fontSize: 10.5 * s,
              height: 1.35,
              color: const Color(0xFF87A9D0),
            ),
          ),
          SizedBox(height: 12 * s),
          Row(
            children: [
              for (final back in CardBack.values) ...[
                if (back != CardBack.values.first) SizedBox(width: 10 * s),
                Expanded(
                  child: Semantics(
                    inMutuallyExclusiveGroup: true,
                    selected: display.cardBack == back,
                    button: true,
                    label: '${back.label} card back',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: Key('settings-swatch-back-${back.name}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPick(back),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: EdgeInsets.all(9 * s),
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(12 * s),
                          border: Border.all(
                            color: display.cardBack == back
                                ? Palette.teal
                                : const Color(0x1FFFFFFF),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            PlayingCard.back(
                              Size(44 * s, 60 * s),
                              back,
                              radius: 6 * s,
                              shadow: false,
                            ),
                            SizedBox(height: 8 * s),
                            Text(
                              back.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5 * s,
                                fontWeight: FontWeight.w500,
                                color: display.cardBack == back
                                    ? Palette.teal
                                    : const Color(0xFF87A9D0),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows, required this.scale});

  final String title;
  final List<SettingRow> rows;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 3 * s),
          child: Kicker(title, scale: s),
        ),
        for (final row in rows) ...[
          SizedBox(height: 8 * s),
          ListenableBuilder(
            listenable: Listenable.merge([
              scope.playSettings,
              scope.displayOptions,
              scope.controller,
            ]),
            builder: (context, _) {
              final value = settingValue(
                row.field,
                scope.playSettings.value,
                scope.displayOptions.value,
              );
              final game = scope.controller.game;
              final live = !game.isWon && scope.controller.hasMove;
              final note =
                  row.nextDeal &&
                      live &&
                      (!row.klondikeOnly || game is KlondikeGame)
                  ? 'Applies to your next deal'
                  : null;
              return _SwitchRow(
                row: row,
                value: value,
                note: note,
                scale: s,
                onChanged: (v) {
                  scope.playSettings.value = applyPlay(
                    row.field,
                    scope.playSettings.value,
                    v,
                  );
                  scope.displayOptions.value = applyDisplay(
                    row.field,
                    scope.displayOptions.value,
                    v,
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }
}

/// The value of a setting by its field name.
bool settingValue(String field, PlaySettings p, DisplayOptions d) =>
    switch (field) {
      'oneTap' => p.oneTap,
      'autoFinish' => p.autoFinish,
      'autoFlip' => p.autoFlip,
      'unlimitedUndo' => p.unlimitedUndo,
      'winnableOnly' => p.winnableOnly,
      'cardAnimations' => p.cardAnimations,
      'sound' => p.sound,
      'music' => p.music,
      'haptics' => p.haptics,
      'leftHanded' => d.leftHanded,
      'largeCards' => d.largeCards,
      'showTimer' => d.showTimer,
      'showMovesAndScore' => d.showMovesAndScore,
      _ => throw ArgumentError.value(field, 'field'),
    };

PlaySettings applyPlay(String field, PlaySettings p, bool v) => switch (field) {
  'oneTap' => p.copyWith(oneTap: v),
  'autoFinish' => p.copyWith(autoFinish: v),
  'autoFlip' => p.copyWith(autoFlip: v),
  'unlimitedUndo' => p.copyWith(unlimitedUndo: v),
  'winnableOnly' => p.copyWith(winnableOnly: v),
  'cardAnimations' => p.copyWith(cardAnimations: v),
  'sound' => p.copyWith(sound: v),
  'music' => p.copyWith(music: v),
  'haptics' => p.copyWith(haptics: v),
  _ => p,
};

DisplayOptions applyDisplay(String field, DisplayOptions d, bool v) =>
    switch (field) {
      'leftHanded' => d.copyWith(leftHanded: v),
      'largeCards' => d.copyWith(largeCards: v),
      'showTimer' => d.copyWith(showTimer: v),
      'showMovesAndScore' => d.copyWith(showMovesAndScore: v),
      _ => d,
    };

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.row,
    required this.value,
    required this.note,
    required this.scale,
    required this.onChanged,
  });

  final SettingRow row;
  final bool value;
  final String? note;
  final double scale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      toggled: value,
      label: row.label,
      hint: row.description,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('settings-row-${row.field}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(12 * s),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 12.5 * s,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 5 * s),
                    Text(
                      row.description,
                      style: TextStyle(
                        fontSize: 10.5 * s,
                        height: 1.35,
                        color: const Color(0xFF87A9D0),
                      ),
                    ),
                    if (note != null) ...[
                      SizedBox(height: 4 * s),
                      Text(
                        note!,
                        key: Key('settings-note-${row.field}'),
                        style: TextStyle(
                          fontSize: 10.5 * s,
                          height: 1.35,
                          color: Palette.teal.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12 * s),
              _Switch(value: value, scale: s),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design's 46×26 track with a 20-point knob (M5 animates it).
class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.scale});

  final bool value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      key: Key('switch-${value ? 'on' : 'off'}'),
      width: 46 * s,
      height: 26 * s,
      decoration: BoxDecoration(
        color: value ? Palette.teal : const Color(0x29FFFFFF),
        borderRadius: BorderRadius.circular(13 * s),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.all(3 * s),
      child: Container(
        width: 20 * s,
        height: 20 * s,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
