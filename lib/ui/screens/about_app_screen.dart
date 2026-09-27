/// About the App (#91).
library;

import 'package:flutter/material.dart' hide Card;
import 'package:honest_solitaire/engine/card.dart';

import '../../app_version.dart';
import '../app.dart';
import '../brand/honest_mark.dart';
import '../card/suit_paths.dart';
import '../content/about_text.dart';
import '../content/links.dart';
import '../theme/palette.dart';
import '../widgets/open_link.dart';
import '../widgets/screen_header.dart';
import 'about_studio_screen.dart';
import '../fonts.dart';
import '../icons/glyphs.dart';

const aboutAppGradient = RadialGradient(
  center: Alignment(-0.52, -0.76),
  radius: 1.1,
  colors: [Palette.feltTop, Palette.feltMid, Palette.feltBottom],
  stops: [0, 0.58, 1],
);

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  final _opener = LinkOpener();

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    return Scaffold(
      backgroundColor: Palette.navy,
      body: ScreenScaffold(
        gap: 15,
        gradient: aboutAppGradient,
        children: [
          ScreenHeader(
            title: 'About the App',
            onBack: () => scope.navigating.pop(context),
            keyPrefix: 'aboutapp',
            scale: s,
          ),
          Panel(
            scale: s,
            color: const Color(0x0DFFFFFF),
            padding: EdgeInsets.all(16 * s),
            child: Row(
              children: [
                IconTile(size: 62 * s),
                SizedBox(width: 14 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Honest Solitaire',
                        style: TextStyle(
                          fontFamily: kFontOutfit,
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 7 * s),
                      Text(
                        'v$appVersion · OFFLINE',
                        key: const Key('aboutapp-version'),
                        style: TextStyle(
                          fontFamily: kFontMono,
                          fontSize: 10 * s,
                          height: 1,
                          letterSpacing: 1.4 * s,
                          fontWeight: FontWeight.w500,
                          color: Palette.mist,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(
            aboutIntro,
            style: TextStyle(
              fontSize: 13.5 * s,
              height: 1.65,
              color: Palette.textSoft,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Kicker("WHAT'S IN IT", scale: s)),
              for (final f in features) ...[
                SizedBox(height: 8 * s),
                Container(
                  key: Key('aboutapp-feature-${features.indexOf(f)}'),
                  padding: EdgeInsets.symmetric(
                    horizontal: 13 * s,
                    vertical: 11 * s,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(11 * s),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 6 * s),
                        child: Container(
                          width: 6 * s,
                          height: 6 * s,
                          decoration: const BoxDecoration(
                            color: Palette.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.title,
                              style: TextStyle(
                                fontSize: 12 * s,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 5 * s),
                            Text(
                              f.text,
                              style: TextStyle(
                                fontSize: 11 * s,
                                height: 1.4,
                                color: Palette.readout,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Container(
            key: const Key('about-promises'),
            padding: EdgeInsets.fromLTRB(15 * s, 14 * s, 15 * s, 14 * s),
            decoration: BoxDecoration(
              color: const Color(0x1A00D6B4),
              borderRadius: BorderRadius.circular(13 * s),
              border: Border.all(color: const Color(0x5200D6B4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Kicker(
                    'THE HONEST PROMISES',
                    scale: s,
                    size: 9,
                    color: Palette.teal,
                  ),
                ),
                SizedBox(height: 11 * s),
                _ChipGrid(chips: promiseChips, scale: s),
                SizedBox(height: 14 * s),
                Semantics(
                  button: true,
                  label: 'Honest Arcade Promises',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const Key('aboutapp-studio'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => scope.navigating.push(
                      Navigator.of(context),
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutStudioScreen(),
                      ),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(12 * s),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11 * s),
                        border: Border.all(color: const Color(0x6600D6B4)),
                      ),
                      child: Text(
                        'Honest Arcade Promises',
                        style: TextStyle(
                          fontSize: 12.5 * s,
                          fontWeight: FontWeight.w600,
                          color: Palette.teal,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8 * s,
            children: [
              Text(
                'MADE BY',
                style: TextStyle(
                  fontFamily: kFontMono,
                  fontSize: 9.5 * s,
                  letterSpacing: 1.1 * s,
                  fontWeight: FontWeight.w500,
                  color: Palette.textFaint,
                ),
              ),
              LinkText(
                label: 'HONEST ARCADE',
                link: siteLink,
                opener: _opener,
                scale: s,
              ),
              Text(
                '·',
                style: TextStyle(fontSize: 9.5 * s, color: Palette.textFaint),
              ),
              LinkText(
                label: 'SOURCE ON GITHUB',
                link: appSourceLink,
                opener: _opener,
                scale: s,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The app icon: the mark on an ink tile with the brand spade.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Palette.ink,
      borderRadius: BorderRadius.circular(size * 15 / 62),
    ),
    child: Padding(
      padding: EdgeInsets.all(size * 7 / 62),
      child: CustomPaint(
        painter: const HonestMarkPainter(),
        foregroundPainter: _TileSpade(),
      ),
    ),
  );
}

class _TileSpade extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final box = size.width * 0.38;
    final origin = Offset((size.width - box) / 2, size.height * 0.66 - box);
    canvas.drawPath(
      suitPathAt(Suit.spades, origin, box),
      Paint()..color = Palette.teal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Seven chips in two columns, the last alone at the left.
class _ChipGrid extends StatelessWidget {
  const _ChipGrid({required this.chips, required this.scale});

  final List<String> chips;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final rows = <Widget>[];
    for (var i = 0; i < chips.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _chip(chips[i], s)),
            SizedBox(width: 7 * s),
            Expanded(
              child: i + 1 < chips.length
                  ? _chip(chips[i + 1], s)
                  : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < chips.length) rows.add(SizedBox(height: 7 * s));
    }
    return Column(children: rows);
  }

  Widget _chip(String text, double s) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
    decoration: BoxDecoration(
      color: const Color(0x12FFFFFF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        GlyphIcon(Glyph.check, size: 10 * s, color: Palette.teal),
        SizedBox(width: 6 * s),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5 * s,
              height: 1,
              letterSpacing: 0.8 * s,
              fontWeight: FontWeight.w500,
              color: Palette.paleText,
            ),
          ),
        ),
      ],
    ),
  );
}
