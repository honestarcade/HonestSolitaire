/// The main menu (#94): the app's home route after the splash.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:honest_solitaire/engine/card.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../../data/app_store.dart';
import '../../data/game_saves.dart';
import '../app.dart';
import '../brand/honest_mark.dart';
import '../card/playing_card.dart';
import '../card/suit_paths.dart';
import '../format.dart';
import '../navigation.dart';
import '../theme/palette.dart';
import '../widgets/screen_header.dart';
import 'about_app_screen.dart';
import 'about_studio_screen.dart';
import 'how_to_play_screen.dart';
import 'new_klondike_screen.dart';
import 'new_spider_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import '../fonts.dart';

const menuGradient = RadialGradient(
  center: Alignment(-0.52, -0.76),
  radius: 1.1,
  colors: [Palette.feltTop, Palette.feltMid, Palette.feltBottom],
  stops: [0, 0.58, 1],
);

/// "DRAW 3 · 42 MOVES" / "2 SUITS · 1 MOVE" for the resume button.
String resumeMeta(Game game) {
  final moves = '${formatCount(game.moves)} MOVE${game.moves == 1 ? '' : 'S'}';
  return switch (game) {
    KlondikeGame k => 'DRAW ${k.options.draw.count} · $moves',
    SpiderGame s =>
      '${s.options.suits.count} SUIT${s.options.suits.count == 1 ? '' : 'S'} · $moves',
  };
}

/// "Couldn't load your saved game and statistics."
String corruptionMessage(Set<StoreDoc> docs) {
  final names = [
    if (docs.contains(StoreDoc.gameKlondike) ||
        docs.contains(StoreDoc.gameSpider))
      'saved game',
    if (docs.contains(StoreDoc.stats)) 'statistics',
    if (docs.contains(StoreDoc.settings)) 'settings',
  ];
  if (names.isEmpty) return '';
  final list = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return "Couldn't load your $list.";
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _announcedBanner = false;

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // The root: system back leaves the app.
        if (!didPop) SystemNavigator.pop();
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([
          scope.saves,
          scope.store.corruptionNotices,
          scope.displayOptions,
        ]),
        builder: (context, _) {
          final target = scope.saves.value.resumeTarget;
          final notices = scope.store.corruptionNotices.value;
          if (notices.isNotEmpty && !_announcedBanner) {
            _announcedBanner = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                SemanticsService.sendAnnouncement(
                  View.of(context),
                  corruptionMessage(notices),
                  TextDirection.ltr,
                );
              }
            });
          }
          if (notices.isEmpty) _announcedBanner = false;
          return ScreenScaffold(
            gap: 16,
            gradient: menuGradient,
            pinned: _AboutRow(
              scale: s,
              onTap: () => _open(context, const AboutStudioScreen()),
            ),
            children: [
              _Wordmark(scale: s),
              if (notices.isNotEmpty)
                _CorruptionBanner(
                  message: corruptionMessage(notices),
                  scale: s,
                  onDismiss: scope.store.dismissNotices,
                ),
              _ResumeButton(
                target: target,
                scale: s,
                onTap: () {
                  if (target == null) {
                    _open(context, const NewKlondikeScreen());
                  } else {
                    continueGame(context);
                  }
                },
              ),
              // Equal heights for the pair inside the scroll view.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _GameCard(
                        key: const Key('menu-klondike'),
                        title: 'Klondike',
                        subtitle: 'Draw 1 or 3 · four foundations',
                        subtitleColor: Palette.readout,
                        accent: Palette.teal,
                        art: const _KlondikeArt(),
                        scale: s,
                        onTap: () => _open(context, const NewKlondikeScreen()),
                      ),
                    ),
                    SizedBox(width: 11 * s),
                    Expanded(
                      child: _GameCard(
                        key: const Key('menu-spider'),
                        title: 'Spider',
                        subtitle: '1, 2 or 4 suits · ten columns',
                        subtitleColor: const Color(0xFFB48CFF),
                        accent: Palette.violet,
                        art: const _SpiderArt(),
                        scale: s,
                        onTap: () => _open(context, const NewSpiderScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Secondary(
                          'Statistics',
                          const Key('menu-stats'),
                          s,
                          () => _open(context, const StatsScreen()),
                        ),
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: _Secondary(
                          'How to play',
                          const Key('menu-howto'),
                          s,
                          () => _open(context, const HowToPlayScreen()),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10 * s),
                  Row(
                    children: [
                      Expanded(
                        child: _Secondary(
                          'Settings',
                          const Key('menu-settings'),
                          s,
                          () => _open(context, const SettingsScreen()),
                        ),
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: _Secondary(
                          'About the app',
                          const Key('menu-about-app'),
                          s,
                          () => _open(context, const AboutAppScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Widget screen) =>
      openScreen(context, screen);
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      label: 'Honest Solitaire, by Honest Arcade, no ads',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 52 * s,
            height: 52 * s,
            child: CustomPaint(
              painter: const HonestMarkPainter(),
              foregroundPainter: _MenuSpade(),
            ),
          ),
          SizedBox(width: 14 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: 'Honest',
                      children: const [
                        TextSpan(
                          text: 'Solitaire',
                          style: TextStyle(color: Palette.teal),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: kFontOutfit,
                      fontSize: 27 * s,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.81 * s,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(height: 7 * s),
                Text(
                  'BY HONEST ARCADE · NO ADS',
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 9 * s,
                    height: 1,
                    letterSpacing: 2.16 * s,
                    fontWeight: FontWeight.w500,
                    color: Palette.mist,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The spade at the design's proportions: 24/64 wide, baseline 42/64.
class _MenuSpade extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final box = size.width * 24 / 64;
    final origin = Offset((size.width - box) / 2, size.height * 42 / 64 - box);
    canvas.drawPath(
      suitPathAt(Suit.spades, origin, box),
      Paint()..color = Palette.teal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CorruptionBanner extends StatelessWidget {
  const _CorruptionBanner({
    required this.message,
    required this.scale,
    required this.onDismiss,
  });

  final String message;
  final double scale;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      key: const Key('menu-corruption-banner'),
      padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 6 * s, 10 * s),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12 * s),
        border: Border.all(color: const Color(0xFFFFB547)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12 * s,
                height: 1.4,
                color: Palette.paleText,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Dismiss',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('menu-corruption-dismiss'),
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    '✕',
                    style: TextStyle(fontSize: 14 * s, color: Palette.mist),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeButton extends StatefulWidget {
  const _ResumeButton({
    required this.target,
    required this.scale,
    required this.onTap,
  });

  final SavedGame? target;
  final double scale;
  final VoidCallback onTap;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final game = widget.target?.game;
    final label = switch (game) {
      null => 'New game',
      KlondikeGame() => 'Continue Klondike',
      SpiderGame() => 'Continue Spider',
    };
    final meta = game == null ? null : resumeMeta(game);
    final spoken = game == null
        ? 'New game'
        : '$label, ${meta!.toLowerCase().replaceAll(' · ', ', ')}';
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('menu-resume'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 18 * s),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF31E7CB) : Palette.teal,
            borderRadius: BorderRadius.circular(16 * s),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  key: const Key('menu-resume-label'),
                  style: TextStyle(
                    fontSize: 18 * s,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                    height: 1,
                  ),
                ),
              ),
              if (meta != null) ...[
                SizedBox(width: 12 * s),
                Text(
                  meta,
                  key: const Key('menu-resume-meta'),
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 11 * s,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: Palette.ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.accent,
    required this.art,
    required this.scale,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Color accent;
  final Widget art;
  final double scale;
  final VoidCallback onTap;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Semantics(
      button: true,
      label: '${widget.title}, ${widget.subtitle}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(
              color: _pressed ? widget.accent : const Color(0x29FFFFFF),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 78 * s, child: widget.art),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * s, 13 * s, 16 * s, 16 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11.5 * s,
                        height: 1.4,
                        color: widget.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// K♠, 7♥ and a back, fanned.
class _KlondikeArt extends StatelessWidget {
  const _KlondikeArt();

  @override
  Widget build(BuildContext context) {
    final back = GameScope.of(context).displayOptions.value.cardBack;
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxHeight / 78;
        final size = Size(34 * s, 46 * s);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3E86), Color(0xFF04213F)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 16 * s,
                top: 18 * s,
                child: PlayingCard(
                  card: const Card(13, Suit.spades, faceUp: true),
                  size: size,
                  back: back,
                  radius: 5 * s,
                ),
              ),
              Positioned(
                left: 38 * s,
                top: 14 * s,
                child: PlayingCard(
                  card: const Card(7, Suit.hearts, faceUp: true),
                  size: size,
                  back: back,
                  radius: 5 * s,
                ),
              ),
              Positioned(
                left: 62 * s,
                top: 10 * s,
                child: PlayingCard.back(size, back, radius: 5 * s),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// J♠, 10♠, 9♥ side by side.
class _SpiderArt extends StatelessWidget {
  const _SpiderArt();

  @override
  Widget build(BuildContext context) {
    final back = GameScope.of(context).displayOptions.value.cardBack;
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxHeight / 78;
        final size = Size(24 * s, 44 * s);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B1F7A), Color(0xFF1B0E3C)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 14 * s,
                top: 16 * s,
                child: PlayingCard(
                  card: const Card(11, Suit.spades, faceUp: true),
                  size: size,
                  back: back,
                  narrow: true,
                  radius: 5 * s,
                ),
              ),
              Positioned(
                left: 42 * s,
                top: 16 * s,
                child: PlayingCard(
                  card: const Card(10, Suit.spades, faceUp: true),
                  size: size,
                  back: back,
                  narrow: true,
                  radius: 5 * s,
                ),
              ),
              Positioned(
                left: 70 * s,
                top: 16 * s,
                child: PlayingCard(
                  card: const Card(9, Suit.hearts, faceUp: true),
                  size: size,
                  back: back,
                  narrow: true,
                  radius: 5 * s,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Secondary extends StatefulWidget {
  const _Secondary(this.label, Key key, this.scale, this.onTap)
    : super(key: key);

  final String label;
  final double scale;
  final VoidCallback onTap;

  @override
  State<_Secondary> createState() => _SecondaryState();
}

class _SecondaryState extends State<_Secondary> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 15 * s),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(
              color: _pressed ? Palette.teal : const Color(0x24FFFFFF),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14 * s,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatefulWidget {
  const _AboutRow({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  State<_AboutRow> createState() => _AboutRowState();
}

class _AboutRowState extends State<_AboutRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Semantics(
      button: true,
      label: 'About Honest Arcade, no ads, no tracking, open source',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('menu-about-studio'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 15 * s),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0x2E00D6B4) : const Color(0x1400D6B4),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: const Color(0x5900D6B4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Honest Arcade',
                      style: TextStyle(
                        fontSize: 13.5 * s,
                        fontWeight: FontWeight.w600,
                        color: Palette.teal,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      'No ads, no tracking, open source.',
                      style: TextStyle(
                        fontSize: 11 * s,
                        height: 1.3,
                        color: const Color(0xFF87A9D0),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * s),
              Text(
                '›',
                style: TextStyle(
                  fontSize: 16 * s,
                  fontWeight: FontWeight.w500,
                  color: Palette.teal,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
