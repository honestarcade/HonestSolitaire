/// The setup screens' option panels (#88, #89): a label, a description and
/// a row of segmented choices, coloured by the game's accent.
library;

import 'package:flutter/material.dart' hide Card;

import '../theme/palette.dart';
import 'screen_header.dart';

/// Klondike is teal, Spider violet; the unselected colours are shared.
class SetupAccent {
  const SetupAccent._({
    required this.border,
    required this.fill,
    required this.text,
    required this.dealFill,
    required this.dealPressed,
    required this.dealText,
  });

  static const teal = SetupAccent._(
    border: Palette.teal,
    fill: Color(0x2400D6B4),
    text: Palette.teal,
    dealFill: Palette.teal,
    dealPressed: Color(0xFF31E7CB),
    dealText: Palette.ink,
  );

  static const violet = SetupAccent._(
    border: Palette.violet,
    fill: Color(0x298448FC),
    text: Palette.textViolet,
    dealFill: Palette.violet,
    dealPressed: Color(0xFF9A68FF),
    dealText: Colors.white,
  );

  final Color border;
  final Color fill;
  final Color text;
  final Color dealFill;
  final Color dealPressed;
  final Color dealText;

  static const unselectedBorder = Color(0x24FFFFFF);
  static const unselectedFill = Color(0x0AFFFFFF);
  static const unselectedText = Palette.paleText;
}

class OptionPanel extends StatelessWidget {
  const OptionPanel({
    super.key,
    required this.label,
    required this.description,
    required this.choices,
    required this.scale,
    this.descriptionKey,
    this.vertical = false,
  });

  final String label;
  final String description;
  final List<Widget> choices;
  final double scale;
  final Key? descriptionKey;

  /// Rows one under another (Spider's suits) instead of a segmented row.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Panel(
      scale: s,
      color: const Color(0x0DFFFFFF),
      padding: EdgeInsets.fromLTRB(15 * s, 14 * s, 15 * s, 14 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5 * s,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            description,
            key: descriptionKey,
            style: TextStyle(
              fontSize: 11 * s,
              height: 1.4,
              color: Palette.textBody,
            ),
          ),
          SizedBox(height: 12 * s),
          if (vertical)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  if (i > 0) SizedBox(height: 8 * s),
                  choices[i],
                ],
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  if (i > 0) SizedBox(width: 8 * s),
                  Expanded(child: choices[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// One segmented choice; the panel's label goes into the semantics so the
/// row reads "Cards per draw, Draw 3, selected".
class ChoiceButton extends StatefulWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.group,
    required this.selected,
    required this.accent,
    required this.scale,
    required this.onTap,
    this.enabled = true,
    this.hint,
    this.child,
  });

  final String label;
  final String group;
  final bool selected;
  final SetupAccent accent;
  final double scale;
  final VoidCallback onTap;
  final bool enabled;
  final String? hint;

  /// Replaces the plain label (Spider's suit rows).
  final Widget? child;

  @override
  State<ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<ChoiceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final a = widget.accent;
    final selected = widget.selected;
    final border = selected || _pressed
        ? a.border
        : SetupAccent.unselectedBorder;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      enabled: widget.enabled,
      button: true,
      label: '${widget.group}, ${widget.label}',
      hint: widget.hint,
      excludeSemantics: true,
      child: Opacity(
        opacity: widget.enabled ? 1 : Palette.disabledOpacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(vertical: 11 * s, horizontal: 8 * s),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? a.fill : SetupAccent.unselectedFill,
              borderRadius: BorderRadius.circular(11 * s),
              border: Border.all(color: border, width: 1.5),
            ),
            child:
                widget.child ??
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: selected ? a.text : SetupAccent.unselectedText,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// The filled Deal button; disabled at 40 % opacity (#58).
class DealButton extends StatefulWidget {
  const DealButton({
    super.key,
    required this.accent,
    required this.scale,
    required this.onPressed,
    this.label = 'Deal',
    this.enabled = true,
  });

  final SetupAccent accent;
  final double scale;
  final VoidCallback onPressed;
  final String label;
  final bool enabled;

  @override
  State<DealButton> createState() => _DealButtonState();
}

class _DealButtonState extends State<DealButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: widget.enabled ? 1 : Palette.disabledOpacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.enabled ? widget.onPressed : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.all(17 * s),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.accent.dealPressed
                  : widget.accent.dealFill,
              borderRadius: BorderRadius.circular(14 * s),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 16 * s,
                fontWeight: FontWeight.w600,
                height: 1,
                color: widget.accent.dealText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's "Keep playing the current game" row.
class KeepPlayingButton extends StatelessWidget {
  const KeepPlayingButton({
    super.key,
    required this.scale,
    required this.onPressed,
  });

  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      button: true,
      label: 'Keep playing the current game',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.all(14 * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: const Color(0x29FFFFFF)),
          ),
          child: Text(
            'Keep playing the current game',
            style: TextStyle(
              fontSize: 13 * s,
              fontWeight: FontWeight.w500,
              height: 1,
              color: Palette.readout,
            ),
          ),
        ),
      ),
    );
  }
}
