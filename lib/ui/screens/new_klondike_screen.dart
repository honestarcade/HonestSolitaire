/// The New Klondike screen (#88): cards per draw, scoring, timer, random or
/// winnable deal, then Deal — or back to the game in progress.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/game.dart';
import 'package:honest_solitaire/engine/scoring.dart';

import '../app.dart';
import '../game/game_event.dart';
import '../navigation.dart';
import '../widgets/option_panel.dart';
import '../widgets/screen_header.dart';
import 'deal_number_field.dart';
import 'loading_screen.dart';

class NewKlondikeScreen extends StatefulWidget {
  const NewKlondikeScreen({super.key});

  @override
  State<NewKlondikeScreen> createState() => _NewKlondikeScreenState();
}

class _NewKlondikeScreenState extends State<NewKlondikeScreen> {
  late DrawMode _draw;
  late ScoringMode _scoring;
  late bool _timed;
  late bool _winnable;
  bool _initialised = false;
  DealNumberInput _number = const Blank();

  /// The Deal choice before a typed number forced Random; restored when
  /// the number is cleared.
  bool? _winnableBeforeNumber;

  static const chosenDealReason = "A chosen deal can't be promised winnable";

  void _onNumber(DealNumberInput input) {
    setState(() {
      final wasForced = _number is Valid;
      _number = input;
      if (input is Valid && !wasForced) {
        _winnableBeforeNumber = _winnable;
        _winnable = false;
      } else if (input is! Valid && wasForced) {
        _winnable = _winnableBeforeNumber ?? _winnable;
        _winnableBeforeNumber = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final scope = GameScope.of(context);
    final last = scope.settingsStore.lastKlondikeOptions;
    _draw = last.draw;
    _scoring = last.scoring;
    _timed = last.timed;
    // Not remembered: Settings is the default every visit (owner).
    _winnable = scope.playSettings.value.winnableOnly;
  }

  KlondikeOptions _options(GameScope scope) => KlondikeOptions(
    draw: _draw,
    scoring: _scoring,
    timed: _timed,
    autoFlip: scope.playSettings.value.autoFlip,
  );

  void _deal() {
    final scope = GameScope.of(context);
    if (scope.navigating.busy || _number is Invalid) return;
    final options = _options(scope);
    if (_number case Valid(:final number)) {
      // A retry of a specific deal: exact, and exempt from the reroll.
      startNewGame(context, KlondikeGame.deal(number, options));
      return;
    }
    if (_winnable) {
      scope.navigating.push(
        Navigator.of(context),
        FadePageRoute<void>(
          builder: (_) => LoadingScreen.search(
            options: options,
            onGame: (game) {
              // The game exists now: the loss of the saved Klondike (if it
              // is not the live one) and the last-used options.
              final s = GameScope.of(context);
              s.statsListener.abandonSaved(GameType.klondike);
              s.settingsStore.setLastKlondikeOptions(game.options);
            },
          ),
        ),
      );
      return;
    }
    final current = keepPlayingTarget(scope, GameType.klondike)?.dealNumber;
    startNewGame(
      context,
      KlondikeGame.deal(freshDealNumber(scope, current), options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    const accent = SetupAccent.teal;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.controller, scope.saves]),
      builder: (context, _) {
        final keep = keepPlayingTarget(scope, GameType.klondike);
        final forced = _number is Valid;
        return ScreenScaffold(
          gap: 12,
          pinned: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DealButton(
                key: const Key('ksetup-deal'),
                accent: accent,
                scale: s,
                enabled: _number is! Invalid,
                onPressed: _deal,
              ),
              if (keep != null) ...[
                SizedBox(height: 9 * s),
                KeepPlayingButton(
                  accent: accent,
                  key: const Key('ksetup-keep'),
                  scale: s,
                  onPressed: () => keepPlaying(context, keep),
                ),
              ],
            ],
          ),
          children: [
            ScreenHeader(
              title: 'New Klondike game',
              kicker: 'STANDARD 52-CARD DEAL',
              onBack: () => scope.navigating.pop(context),
              keyPrefix: 'ksetup',
              scale: s,
            ),
            OptionPanel(
              label: 'Cards per draw',
              description: 'Draw three is the classic newspaper game; draw one is kinder.',
              scale: s,
              choices: [
                for (final (mode, label) in [
                  (DrawMode.one, 'Draw 1'),
                  (DrawMode.three, 'Draw 3'),
                ])
                  ChoiceButton(
                    key: Key('ksetup-draw-${mode.name}'),
                    label: label,
                    group: 'Cards per draw',
                    selected: _draw == mode,
                    accent: accent,
                    scale: s,
                    onTap: () => setState(() => _draw = mode),
                  ),
              ],
            ),
            OptionPanel(
              label: 'Scoring',
              description: 'Standard points, Vegas dollars, or play with no score at all.',
              scale: s,
              choices: [
                for (final (mode, label) in [
                  (ScoringMode.standard, 'Standard'),
                  (ScoringMode.vegas, 'Vegas'),
                  (ScoringMode.none, 'None'),
                ])
                  ChoiceButton(
                    key: Key('ksetup-scoring-${mode.name}'),
                    label: label,
                    group: 'Scoring',
                    selected: _scoring == mode,
                    accent: accent,
                    scale: s,
                    onTap: () => setState(() => _scoring = mode),
                  ),
              ],
            ),
            OptionPanel(
              label: 'Timer',
              description:
                  'Time the game and record a best time, or play untimed.',
              scale: s,
              choices: [
                for (final (value, label) in [
                  (true, 'Timed'),
                  (false, 'Untimed'),
                ])
                  ChoiceButton(
                    key: Key('ksetup-timed-${value ? 'on' : 'off'}'),
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
              label: 'Deal',
              description: forced
                  ? chosenDealReason
                  : 'Winnable deals are drawn from solvable shuffles only.',
              descriptionKey: Key(
                forced ? 'deal-number-reason' : 'ksetup-deal-description',
              ),
              scale: s,
              choices: [
                for (final (value, label) in [
                  (false, 'Random deal'),
                  (true, 'Winnable only'),
                ])
                  ChoiceButton(
                    key: Key('ksetup-deal-${value ? 'winnable' : 'random'}'),
                    label: label,
                    group: 'Deal',
                    selected: _winnable == value,
                    accent: accent,
                    scale: s,
                    enabled: !(forced && value),
                    hint: forced && value ? chosenDealReason : null,
                    onTap: () => setState(() => _winnable = value),
                  ),
              ],
            ),
            DealNumberField(accent: accent, scale: s, onChanged: _onNumber),
          ],
        );
      },
    );
  }
}
