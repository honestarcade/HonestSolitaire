/// The New Spider screen (#89): one, two or four suits, the timer and the
/// empty-column rule, then Deal.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/deck.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../app.dart';
import '../card/suit_paths.dart';
import '../game/game_event.dart';
import '../navigation.dart';
import '../widgets/option_panel.dart';
import '../widgets/screen_header.dart';
import 'deal_number_field.dart';
import '../theme/palette.dart';

/// The design's three rows.
const suitRows = [
  (SpiderSuits.one, 'One suit', 'Spiderette. A gentle warm-up.', [Suit.spades]),
  (
    SpiderSuits.two,
    'Two suits',
    'The standard game.',
    [Suit.spades, Suit.hearts],
  ),
  (
    SpiderSuits.four,
    'Four suits',
    'The real thing. Around one in twenty falls.',
    [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs],
  ),
];

String suitName(Suit suit) => switch (suit) {
  Suit.spades => 'spades',
  Suit.hearts => 'hearts',
  Suit.diamonds => 'diamonds',
  Suit.clubs => 'clubs',
};

String _spoken(List<Suit> suits) {
  final names = suits.map(suitName).toList();
  if (names.length == 1) return names.single;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

class NewSpiderScreen extends StatefulWidget {
  const NewSpiderScreen({super.key});

  @override
  State<NewSpiderScreen> createState() => _NewSpiderScreenState();
}

class _NewSpiderScreenState extends State<NewSpiderScreen> {
  late SpiderSuits _suits;
  late bool _timed;
  late bool _relaxed;
  bool _initialised = false;
  DealNumberInput _number = const Blank();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final last = GameScope.of(context).settingsStore.lastSpiderOptions;
    _suits = last.suits;
    _timed = last.timed;
    _relaxed = last.relaxed;
  }

  void _deal() {
    final scope = GameScope.of(context);
    if (scope.navigating.busy || _number is Invalid) return;
    final options = SpiderOptions(
      suits: _suits,
      timed: _timed,
      relaxed: _relaxed,
      autoFlip: scope.playSettings.value.autoFlip,
    );
    if (_number case Valid(:final number)) {
      // A retry of a specific deal: exact, and exempt from the reroll.
      startNewGame(context, SpiderGame.deal(number, options));
      return;
    }
    final current = keepPlayingTarget(scope, GameType.spider)?.dealNumber;
    startNewGame(
      context,
      SpiderGame.deal(freshDealNumber(scope, current), options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    const accent = SetupAccent.violet;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.controller, scope.saves]),
      builder: (context, _) {
        final keep = keepPlayingTarget(scope, GameType.spider);
        return ScreenScaffold(
          gap: 12,
          pinned: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DealButton(
                key: const Key('ssetup-deal'),
                accent: accent,
                scale: s,
                enabled: _number is! Invalid,
                onPressed: _deal,
              ),
              if (keep != null) ...[
                SizedBox(height: 9 * s),
                KeepPlayingButton(
                  key: const Key('ssetup-keep'),
                  scale: s,
                  onPressed: () => keepPlaying(context, keep),
                ),
              ],
            ],
          ),
          children: [
            ScreenHeader(
              title: 'New Spider game',
              kicker: 'TWO DECKS · 104 CARDS',
              kickerColor: accent.text,
              onBack: () => scope.navigating.pop(context),
              keyPrefix: 'ssetup',
              scale: s,
            ),
            OptionPanel(
              label: 'Suits in play',
              description: 'Fewer suits, easier game. The board and the deal count never change.',
              scale: s,
              vertical: true,
              choices: [
                for (final (suits, label, description, glyphs) in suitRows)
                  ChoiceButton(
                    key: Key('ssetup-suits-${suits.name}'),
                    label: '$label, ${_spoken(glyphs)}. $description',
                    group: 'Suits in play',
                    selected: _suits == suits,
                    accent: accent,
                    scale: s,
                    onTap: () => setState(() => _suits = suits),
                    child: _SuitRow(
                      label: label,
                      description: description,
                      glyphs: glyphs,
                      selected: _suits == suits,
                      scale: s,
                    ),
                  ),
              ],
            ),
            OptionPanel(
              label: 'Timer',
              description: 'Spider games run long — the timer is optional.',
              scale: s,
              choices: [
                for (final (value, label) in [
                  (true, 'Timed'),
                  (false, 'Untimed'),
                ])
                  ChoiceButton(
                    key: Key('ssetup-timed-${value ? 'on' : 'off'}'),
                    label: label,
                    group: 'Timer',
                    selected: _timed == value,
                    accent: accent,
                    scale: s,
                    onTap: () => setState(() => _timed = value),
                  ),
              ],
            ),
            OptionPanel(
              label: 'Empty-column rule',
              description: 'Relaxed lets you deal a row with a column empty.',
              scale: s,
              choices: [
                for (final (value, label) in [
                  (false, 'Strict'),
                  (true, 'Relaxed'),
                ])
                  ChoiceButton(
                    key: Key('ssetup-rule-${value ? 'relaxed' : 'strict'}'),
                    label: label,
                    group: 'Empty-column rule',
                    selected: _relaxed == value,
                    accent: accent,
                    scale: s,
                    onTap: () => setState(() => _relaxed = value),
                  ),
              ],
            ),
            DealNumberField(
              accent: accent,
              scale: s,
              onChanged: (input) => setState(() => _number = input),
            ),
          ],
        );
      },
    );
  }
}

class _SuitRow extends StatelessWidget {
  const _SuitRow({
    required this.label,
    required this.description,
    required this.glyphs,
    required this.selected,
    required this.scale,
  });

  final String label;
  final String description;
  final List<Suit> glyphs;
  final bool selected;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: selected
                        ? SetupAccent.violet.text
                        : SetupAccent.unselectedText,
                  ),
                ),
                SizedBox(height: 5 * s),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10.5 * s,
                    height: 1.3,
                    color: Palette.textBody,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * s),
          Row(
            children: [
              for (var i = 0; i < glyphs.length; i++) ...[
                if (i > 0) SizedBox(width: 4 * s),
                CustomPaint(
                  size: Size(15 * s, 15 * s),
                  painter: _SuitGlyph(
                    glyphs[i],
                    selected ? SetupAccent.violet.text : Palette.textMuted,
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

class _SuitGlyph extends CustomPainter {
  const _SuitGlyph(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      suitPathAt(suit, Offset.zero, size.width),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SuitGlyph old) => old.suit != suit || old.color != color;
}
