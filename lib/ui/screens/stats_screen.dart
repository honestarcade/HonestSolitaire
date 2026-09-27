/// The Statistics screen (#92): tabs, six headline cards, the breakdown by
/// draw mode or suit count, and a reset that asks first.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';

import '../../data/stats.dart';
import '../app.dart';
import '../motion.dart';
import '../format.dart';
import '../game/game_event.dart';
import '../theme/palette.dart';
import '../widgets/game_tabs.dart';
import '../widgets/screen_header.dart';
import '../fonts.dart';

const resetConfirmText =
    'Clears every recorded game, streak, best time and score for both '
    'Klondike and Spider. Nothing was ever uploaded by this app, so it has no '
    'other copy.';

const _red = Color(0xFFE05A4E);
const dash = '—';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.game});

  final GameType? game;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  GameType? _tab;
  bool _confirming = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pick(GameType type) {
    setState(() => _tab = type);
    if (!_scroll.hasClients) return;
    final duration = GameScope.motionOf(context).ui(bannerFade);
    if (duration == Duration.zero) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: duration, curve: Curves.easeOut);
    }
  }

  void _askReset() {
    setState(() => _confirming = true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Reset all statistics?',
      TextDirection.ltr,
    );
  }

  void _cancel() => setState(() => _confirming = false);

  void _reset() {
    setState(() => _confirming = false);
    GameScope.of(context).stats.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    final tab = _tab ??= widget.game ?? GameType.of(scope.controller.game);
    return PopScope(
      canPop: !_confirming,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _confirming) _cancel();
      },
      child: ListenableBuilder(
        listenable: scope.stats,
        builder: (context, _) {
          final doc = scope.stats.document;
          final stats = doc[tab];
          final empty =
              doc.klondike.total.played == 0 && doc.spider.total.played == 0;
          return Stack(
            children: [
              ScreenScaffold(
                controller: _scroll,
                gap: 12,
                pinned: _ResetButton(
                  enabled: !empty,
                  scale: s,
                  onPressed: _askReset,
                ),
                children: [
                  ScreenHeader(
                    title: 'Statistics',
                    onBack: () => scope.navigating.pop(context),
                    keyPrefix: 'stats',
                    scale: s,
                  ),
                  GameTabs(
                    selected: tab,
                    onChanged: _pick,
                    keyPrefix: 'stats',
                    scale: s,
                  ),
                  _Cards(stats: stats, scale: s),
                  _Breakdown(type: tab, stats: stats, scale: s),
                ],
              ),
              if (_confirming)
                _ConfirmCard(scale: s, onCancel: _cancel, onReset: _reset),
            ],
          );
        },
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.stats, required this.scale});

  final GameStats stats;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final t = stats.total;
    final played = t.played > 0;
    final cards = [
      (
        'played',
        'GAMES PLAYED',
        played ? formatCount(t.played) : dash,
        'Since install',
        false,
      ),
      (
        'winrate',
        'WIN RATE',
        played ? formatPercent(t.won, t.played) : dash,
        played ? '${formatCount(t.won)} won' : '$dash won',
        true,
      ),
      (
        'besttime',
        'BEST TIME',
        t.bestTimeMs == null
            ? dash
            : formatClock(Duration(milliseconds: t.bestTimeMs!)),
        'Fastest finish',
        false,
      ),
      (
        'fewest',
        'FEWEST MOVES',
        t.fewestMoves == null ? dash : formatCount(t.fewestMoves!),
        'In a won game',
        false,
      ),
      (
        'streak',
        'CURRENT STREAK',
        played ? formatCount(t.streak) : dash,
        'Consecutive wins',
        false,
      ),
      (
        'highscore',
        'HIGH SCORE',
        t.highScore == null ? dash : formatCount(t.highScore!),
        'Total play ${played ? formatPlayTime(t.playMs) : dash}',
        false,
      ),
    ];
    final s = scale;
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(
        // Equal heights across the pair; the scroll view gives no height.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _card(cards[i], s)),
              SizedBox(width: 9 * s),
              Expanded(child: _card(cards[i + 1], s)),
            ],
          ),
        ),
      );
      if (i + 2 < cards.length) rows.add(SizedBox(height: 9 * s));
    }
    return Column(children: rows);
  }

  Widget _card((String, String, String, String, bool) card, double s) {
    final (name, label, value, sub, teal) = card;
    return Semantics(
      label: '${_sentence(label)}, ${_spoken(value)}, ${_spoken(sub)}',
      excludeSemantics: true,
      child: Container(
        key: Key('stats-card-$name'),
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(
          color: teal ? const Color(0x2400D6B4) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(13 * s),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: kFontMono,
                fontSize: 9 * s,
                height: 1,
                letterSpacing: 1.3 * s,
                fontWeight: FontWeight.w500,
                color: Palette.mist,
              ),
            ),
            SizedBox(height: 8 * s),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: Key('stats-value-$name'),
                style: TextStyle(
                  fontSize: 21 * s,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: teal ? Palette.teal : Colors.white,
                ),
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              sub,
              key: Key('stats-sub-$name'),
              style: TextStyle(
                fontSize: 10.5 * s,
                height: 1.3,
                color: Palette.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sentence(String caps) =>
      caps[0] + caps.substring(1).toLowerCase();

  static String _spoken(String text) =>
      text.replaceAll(dash, 'none').replaceAll('%', ' percent');
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.type,
    required this.stats,
    required this.scale,
  });

  final GameType type;
  final GameStats stats;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final klondike = type == GameType.klondike;
    final rows = klondike
        ? [
            ('draw1', 'Draw one', Palette.teal),
            ('draw3', 'Draw three', Palette.blue),
          ]
        : [
            ('one', 'One suit', Palette.teal),
            ('two', 'Two suits', Palette.blue),
            ('four', 'Four suits', Palette.violet),
          ];
    return Panel(
      scale: s,
      color: const Color(0x0DFFFFFF),
      padding: EdgeInsets.all(15 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Kicker(
              klondike ? 'BY DRAW MODE' : 'BY SUIT COUNT',
              scale: s,
            ),
          ),
          for (final (key, label, color) in rows) ...[
            SizedBox(height: 10 * s),
            _row(
              key,
              label,
              color,
              stats.mode(key).won,
              stats.mode(key).played,
              s,
            ),
          ],
          if (klondike) ...[
            SizedBox(height: 10 * s),
            _vegas(stats.vegas ?? const VegasStats(), s),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String key,
    String label,
    Color color,
    int won,
    int played,
    double s,
  ) {
    final value = played > 0
        ? '${formatCount(won)} / ${formatCount(played)} · ${formatPercent(won, played)}'
        : '0 / 0 · $dash';
    final spoken = played > 0
        ? '$label, $won won of $played, ${(won * 100 / played).round()} percent'
        : '$label, no games yet';
    return _BarRow(
      key: Key('stats-row-$key'),
      label: label,
      value: value,
      spoken: spoken,
      fraction: played > 0 ? won / played : 0,
      color: color,
      scale: s,
    );
  }

  Widget _vegas(VegasStats v, double s) {
    final value = v.played > 0
        ? '${v.dollars < 0 ? '−\$${formatCount(-v.dollars)}' : '+\$${formatCount(v.dollars)}'} lifetime'
        : dash;
    final spoken = v.played > 0
        ? 'Vegas scoring, ${v.dollars < 0 ? 'minus' : 'plus'} ${formatCount(v.dollars.abs())} dollars lifetime'
        : 'Vegas scoring, no games yet';
    return _BarRow(
      key: const Key('stats-row-vegas'),
      label: 'Vegas scoring',
      value: value,
      spoken: spoken,
      fraction: v.played > 0 ? v.won / v.played : 0,
      color: Palette.violet,
      scale: s,
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.spoken,
    required this.fraction,
    required this.color,
    required this.scale,
  });

  final String label;
  final String value;
  final String spoken;
  final double fraction;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5 * s,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: Palette.paleText,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11.5 * s,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  fontFamily: kFontMono,
                  color: Palette.readout,
                ),
              ),
            ],
          ),
          SizedBox(height: 7 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x17FFFFFF)),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({
    required this.enabled,
    required this.scale,
    required this.onPressed,
  });

  final bool enabled;
  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Reset statistics',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : Palette.disabledOpacity,
        child: GestureDetector(
          key: const Key('stats-reset'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: EdgeInsets.all(14 * s),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13 * s),
              border: Border.all(color: _red.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Reset statistics',
              style: TextStyle(
                fontSize: 13 * s,
                fontWeight: FontWeight.w500,
                height: 1,
                color: Palette.errorText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.scale,
    required this.onCancel,
    required this.onReset,
  });

  final double scale;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Positioned.fill(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: GestureDetector(
          // The scrim does nothing (planner).
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            color: const Color(0xD1030E20),
            alignment: Alignment.center,
            padding: EdgeInsets.all(26 * s),
            child: Container(
              key: const Key('stats-confirm'),
              constraints: const BoxConstraints(maxWidth: 440),
              padding: EdgeInsets.all(22 * s),
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(18 * s),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 50,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Reset statistics?',
                      style: TextStyle(
                        fontSize: 17 * s,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(height: 11 * s),
                  Text(
                    resetConfirmText,
                    style: TextStyle(
                      fontSize: 12.5 * s,
                      height: 1.55,
                      color: Palette.textSoft,
                    ),
                  ),
                  SizedBox(height: 18 * s),
                  Row(
                    children: [
                      Expanded(
                        child: _button(
                          'Cancel',
                          const Key('stats-confirm-cancel'),
                          onCancel,
                          const Color(0x0FFFFFFF),
                          Colors.white,
                          const Color(0x33FFFFFF),
                          s,
                        ),
                      ),
                      SizedBox(width: 9 * s),
                      Expanded(
                        child: _button(
                          'Reset',
                          const Key('stats-confirm-reset'),
                          onReset,
                          _red,
                          Colors.white,
                          null,
                          s,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    String label,
    Key key,
    VoidCallback onTap,
    Color bg,
    Color fg,
    Color? border,
    double s,
  ) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: EdgeInsets.all(13 * s),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12 * s),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13 * s,
            fontWeight: FontWeight.w600,
            height: 1,
            color: fg,
          ),
        ),
      ),
    ),
  );
}
