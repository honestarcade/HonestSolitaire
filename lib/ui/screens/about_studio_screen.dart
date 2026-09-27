/// About Honest Arcade (#91).
library;

import 'package:flutter/material.dart' hide Card;

import '../app.dart';
import '../brand/honest_mark.dart';
import '../content/about_text.dart';
import '../content/links.dart';
import '../theme/palette.dart';
import '../widgets/open_link.dart';
import '../widgets/screen_header.dart';
import '../fonts.dart';
import '../icons/glyphs.dart';

const aboutStudioGradient = RadialGradient(
  center: Alignment(0.56, -0.76),
  radius: 1.1,
  colors: [Palette.feltTop, Palette.feltMid, Palette.feltBottom],
  stops: [0, 0.58, 1],
);

class AboutStudioScreen extends StatefulWidget {
  const AboutStudioScreen({super.key});

  @override
  State<AboutStudioScreen> createState() => _AboutStudioScreenState();
}

class _AboutStudioScreenState extends State<AboutStudioScreen> {
  final _opener = LinkOpener();

  @override
  Widget build(BuildContext context) {
    final scope = GameScope.of(context);
    final s = screenScale(context);
    return Scaffold(
      backgroundColor: Palette.navy,
      body: ScreenScaffold(
        gap: 15,
        gradient: aboutStudioGradient,
        children: [
          ScreenHeader(
            title: 'About Honest Arcade',
            onBack: () => scope.navigating.pop(context),
            keyPrefix: 'aboutstudio',
            scale: s,
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 6 * s, bottom: 2 * s),
              child: SizedBox(
                width: 120 * s,
                height: 120 * s,
                child: const CustomPaint(painter: HonestMarkPainter()),
              ),
            ),
          ),
          Text(
            studioParagraphs[0],
            style: TextStyle(
              fontSize: 14 * s,
              height: 1.65,
              color: const Color(0xFFC6DAF0),
            ),
          ),
          Text(
            studioParagraphs[1],
            style: TextStyle(
              fontSize: 14 * s,
              height: 1.65,
              color: Palette.mist,
            ),
          ),
          Semantics(
            link: true,
            label:
                'Support Honest Arcade. $supportText ${contributeLink.display}, opens in browser',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('about-support'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _opener.open(context, contributeLink),
              child: Container(
                padding: EdgeInsets.fromLTRB(15 * s, 14 * s, 15 * s, 14 * s),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x2100D6B4), Color(0x218448FC)],
                  ),
                  borderRadius: BorderRadius.circular(14 * s),
                  border: Border.all(color: const Color(0x4700D6B4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(
                      'SUPPORT HONEST ARCADE',
                      scale: s,
                      color: Palette.teal,
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      supportText,
                      style: TextStyle(
                        fontSize: 12.5 * s,
                        height: 1.55,
                        color: const Color(0xFFC6DAF0),
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text.rich(
                      TextSpan(
                        text: '${contributeLink.display} ',
                        children: [
                          inlineGlyph(Glyph.arrow, _supportLinkStyle(s)),
                        ],
                      ),
                      style: _supportLinkStyle(s),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Kicker('OUR PROMISES', scale: s)),
              for (final p in promises) ...[
                SizedBox(height: 8 * s),
                Container(
                  key: Key('aboutstudio-promise-${promises.indexOf(p)}'),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * s,
                    vertical: 12 * s,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(12 * s),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 1 * s),
                        child: GlyphIcon(
                          Glyph.check,
                          size: 12 * s,
                          color: p.color,
                        ),
                      ),
                      SizedBox(width: 11 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: TextStyle(
                                fontSize: 12.5 * s,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 5 * s),
                            Text(
                              p.text,
                              style: TextStyle(
                                fontSize: 11 * s,
                                height: 1.45,
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8 * s,
            runSpacing: 8 * s,
            children: [
              _pill('NO ADS', const Color(0x2400D6B4), Palette.teal, s),
              _pill(
                'NO TRACKING',
                const Color(0x290076F1),
                const Color(0xFF6FB4FF),
                s,
              ),
              _pill(
                'OPEN SOURCE',
                const Color(0x298448FC),
                const Color(0xFFB48CFF),
                s,
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8 * s,
            children: [
              LinkText(
                label: 'HONESTARCADE.APP',
                link: siteLink,
                opener: _opener,
                scale: s,
              ),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 9.5 * s,
                  color: const Color(0xFF4E739F),
                ),
              ),
              LinkText(
                label: 'SOURCE ON GITHUB',
                link: studioSourceLink,
                opener: _opener,
                scale: s,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static TextStyle _supportLinkStyle(double s) => TextStyle(
    fontSize: 11.5 * s,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1,
  );

  Widget _pill(String text, Color bg, Color fg, double s) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: kFontMono,
        fontSize: 10.5 * s,
        height: 1,
        letterSpacing: 1 * s,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
    ),
  );
}
