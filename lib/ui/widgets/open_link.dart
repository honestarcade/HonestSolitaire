/// Opens a link in the phone's browser through the platform channel (#91)
/// and says so when no browser can take it. Never a crash.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import '../app.dart';
import '../content/links.dart';
import '../fonts.dart';
import '../icons/glyphs.dart';
import '../theme/palette.dart';

/// Per-screen: a second tap while a call runs is ignored.
class LinkOpener {
  bool _busy = false;

  Future<void> open(BuildContext context, Link link) async {
    if (_busy) return;
    _busy = true;
    final scope = GameScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await scope.platform.openUrl(link.url);
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    } finally {
      _busy = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          key: const Key('about-snackbar'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0B3A7E),
          duration: const Duration(seconds: 4),
          content: Text(
            "COULDN'T OPEN ${link.display.toUpperCase()} — NO BROWSER FOUND",
            style: const TextStyle(
              fontFamily: kFontMono,
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
              color: Palette.paleText,
            ),
          ),
        ),
      );
    }
  }
}

/// A mono-caps link row with the external-link glyph, 48 dp hit area.
TextStyle _linkStyle(double s) => TextStyle(
  fontFamily: kFontMono,
  fontSize: 9.5 * s,
  height: 1.2,
  letterSpacing: 1.1 * s,
  fontWeight: FontWeight.w500,
  color: Palette.mist,
);

class LinkText extends StatelessWidget {
  const LinkText({
    super.key,
    required this.label,
    required this.link,
    required this.opener,
    required this.scale,
  });

  final String label;
  final Link link;
  final LinkOpener opener;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Semantics(
      link: true,
      label: '$label, opens in browser',
      onTap: () => opener.open(context, link),
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('about-link-${link.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => opener.open(context, link),
        // Sized to its label: inside a Wrap, an aligned Container would take
        // the whole line and stack every link (#160).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Container(
              padding: EdgeInsets.only(bottom: 2 * s),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x667FA6D8))),
              ),
              child: Text.rich(
                TextSpan(
                  text: '$label ',
                  children: [inlineGlyph(Glyph.external, _linkStyle(s))],
                ),
                style: _linkStyle(s),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
