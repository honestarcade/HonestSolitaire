/// The tool row (#79): UNDO, HINT, FINISH or DEAL n, RESTART, NEW — five
/// equal buttons along the bottom, reversed for left-handed play; the icons
/// are #100's vector glyphs.
library;

import 'package:flutter/material.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../format.dart';
import '../theme/palette.dart';
import 'game_controller.dart';
import '../fonts.dart';
import '../icons/glyphs.dart';

class ToolRow extends StatelessWidget {
  const ToolRow({
    super.key,
    required this.controller,
    required this.scale,
    this.onNew,
  });

  final GameController controller;
  final double scale;

  /// NEW opens the setup screen (#93); null deals directly (board-only
  /// tests).
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: ListenableBuilder(
      listenable: Listenable.merge([controller, controller.displayOptions]),
      builder: (context, _) {
        final game = controller.game;
        final won = game.isWon;
        final blocked = won || controller.isPaused;
        final tools = <_Tool>[
          _Tool(
            key: 'undo',
            glyph: Glyph.undo,
            label: 'UNDO',
            semantics: 'Undo',
            enabled: !blocked && controller.canUndo,
            onPressed: controller.undo,
          ),
          _Tool(
            key: 'hint',
            glyph: Glyph.hint,
            label: 'HINT',
            semantics: 'Hint',
            enabled: !blocked,
            onPressed: controller.hint,
          ),
          if (game is KlondikeGame)
            _Tool(
              key: 'finish',
              glyph: Glyph.finish,
              label: 'FINISH',
              semantics: 'Finish',
              enabled: !blocked && controller.canFinish,
              accent: true,
              onPressed: controller.finish,
            )
          else
            _Tool(
              key: 'deal',
              glyph: Glyph.deal,
              label: 'DEAL ${formatCount(controller.dealsLeft)}',
              semantics: 'Deal, ${controller.dealsLeft} left',
              enabled: !blocked && controller.dealsLeft > 0,
              accent: true,
              onPressed: controller.dealRow,
            ),
          _Tool(
            key: 'restart',
            glyph: Glyph.restart,
            label: 'RESTART',
            semantics: 'Restart',
            enabled: !blocked,
            onPressed: controller.restart,
          ),
          _Tool(
            key: 'new',
            glyph: Glyph.newGame,
            label: 'NEW',
            semantics: 'New deal',
            enabled: !blocked,
            onPressed: onNew ?? controller.newDeal,
          ),
        ];
        final ordered = controller.display.leftHanded
            ? tools.reversed.toList()
            : tools;
        return Padding(
          padding: EdgeInsets.fromLTRB(14 * scale, 0, 14 * scale, 22 * scale),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                for (var i = 0; i < ordered.length; i++) ...[
                  if (i > 0) SizedBox(width: 8 * scale),
                  Expanded(
                    child: _ToolButton(tool: ordered[i], scale: scale),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Tool {
  const _Tool({
    required this.key,
    required this.glyph,
    required this.label,
    required this.semantics,
    required this.enabled,
    required this.onPressed,
    this.accent = false,
  });

  final String key;
  final Glyph glyph;
  final String label;
  final String semantics;
  final bool enabled;
  final VoidCallback onPressed;
  final bool accent;
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({required this.tool, required this.scale});

  final _Tool tool;
  final double scale;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    final s = widget.scale;
    final accent = t.accent && t.enabled;
    final edge = _pressed
        ? Palette.teal
        : accent
        ? const Color(0x6600D6B4)
        : const Color(0x24FFFFFF);
    final fill = accent ? const Color(0x1F00D6B4) : const Color(0x0FFFFFFF);
    final fg = accent ? Palette.teal : Palette.paleText;
    return Semantics(
      button: true,
      enabled: t.enabled,
      label: t.semantics,
      excludeSemantics: true,
      child: Opacity(
        opacity: t.enabled ? 1 : Palette.disabledOpacity,
        child: GestureDetector(
          key: Key('tool-${t.key}'),
          behavior: HitTestBehavior.opaque,
          onTapDown: t.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: t.enabled
              ? () {
                  t.onPressed();
                  Future<void>.delayed(const Duration(milliseconds: 120), () {
                    if (mounted) setState(() => _pressed = false);
                  });
                }
              : null,
          child: Container(
            constraints: BoxConstraints(
              minHeight: 48,
              maxHeight: 50 * s < 48 ? 48 : 50 * s,
            ),
            height: 50 * s,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: edge),
              borderRadius: BorderRadius.circular(13 * s),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The icon is decorative here: the button's label names it.
                KeyedSubtree(
                  key: Key('tool-${t.key}-glyph'),
                  child: GlyphIcon(t.glyph, size: 15 * s, color: fg),
                ),
                SizedBox(height: 5 * s),
                Text(
                  t.label,
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 8.5 * s,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1 * 8.5 * s,
                    color: fg,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
