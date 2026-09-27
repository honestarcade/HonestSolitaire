/// How to play (#90): Klondike and Spider tabs with the rules as cards, and
/// the gestures.
library;

import 'package:flutter/material.dart' hide Card;

import '../app.dart';
import '../content/rules_text.dart';
import '../game/game_event.dart';
import '../theme/palette.dart';
import '../widgets/game_tabs.dart';
import '../widgets/screen_header.dart';
import '../fonts.dart';

class HowToPlayScreen extends StatefulWidget {
  /// [game] is the tab to open on (the pause card passes its game); null
  /// falls back to the controller's game, then the last played, then
  /// Klondike.
  const HowToPlayScreen({super.key, this.game});

  final GameType? game;

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  GameType? _tab;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pick(GameType type) {
    setState(() => _tab = type);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    final tab = _tab ??= widget.game ?? GameType.of(scope.controller.game);
    final cards = rulesFor(tab);
    return ScreenScaffold(
      controller: _scroll,
      gap: 12,
      children: [
        ScreenHeader(
          title: 'How to play',
          onBack: () => scope.navigating.pop(context),
          keyPrefix: 'howto',
          scale: s,
        ),
        GameTabs(selected: tab, onChanged: _pick, keyPrefix: 'howto', scale: s),
        for (var i = 0; i < cards.length; i++)
          _RuleCardView(card: cards[i], highlighted: i == 0, scale: s),
        Panel(
          scale: s,
          color: const Color(0x0DFFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Kicker('GESTURES', scale: s, size: 9),
              ),
              SizedBox(height: 11 * s),
              for (var i = 0; i < gestures.length; i++) ...[
                if (i > 0) SizedBox(height: 8 * s),
                _GestureRow(gesture: gestures[i], scale: s),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleCardView extends StatelessWidget {
  const _RuleCardView({
    required this.card,
    required this.highlighted,
    required this.scale,
  });

  final RuleCard card;
  final bool highlighted;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      container: true,
      child: Container(
        key: Key('howto-card-${card.slug}'),
        padding: EdgeInsets.fromLTRB(15 * s, 14 * s, 15 * s, 14 * s),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0x1C00D6B4)
              : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(13 * s),
          border: highlighted
              ? Border.all(color: const Color(0x5700D6B4))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Kicker(
                card.tag,
                scale: s,
                size: 9,
                color: highlighted ? Palette.teal : Palette.textKicker,
              ),
            ),
            SizedBox(height: 9 * s),
            Text(
              card.body,
              style: TextStyle(
                fontSize: 12.5 * s,
                height: 1.6,
                color: Palette.paleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GestureRow extends StatelessWidget {
  const _GestureRow({required this.gesture, required this.scale});

  final Gesture gesture;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      label: '${gesture.name}. ${gesture.text}',
      excludeSemantics: true,
      child: Row(
        key: Key('howto-gesture-${gesture.slug}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 5 * s),
            decoration: BoxDecoration(
              color: const Color(0x2400D6B4),
              borderRadius: BorderRadius.circular(7 * s),
            ),
            child: Text(
              gesture.name,
              style: TextStyle(
                fontFamily: kFontMono,
                fontSize: 9.5 * s,
                height: 1,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5 * s,
                color: Palette.teal,
              ),
            ),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2 * s),
              child: Text(
                gesture.text,
                style: TextStyle(
                  fontSize: 11.5 * s,
                  height: 1.45,
                  color: Palette.textSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
