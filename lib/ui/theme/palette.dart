/// The design's colour tokens (`Honest Solitaire.dc.html`, brand sheet and
/// board), in one place so every screen reads the same values. Text tokens
/// that the design drew too dim for WCAG AA are nudged in the same hue
/// (#102); `nudges` records each one's design value so the contrast guard
/// re-derives it, and `textPairs` declares every text-on-surface pair the
/// guard checks.
library;

import 'package:flutter/painting.dart';

/// One text (or graphic) colour on the surfaces it is drawn over.
class TextPair {
  const TextPair(
    this.name,
    this.fg,
    this.surfaces, {
    this.large = false,
    this.graphic = false,
    this.disabled = false,
  });

  final String name;
  final Color fg;

  /// Opaque surfaces; a translucent fill is composited by the caller.
  final List<Color> surfaces;

  /// ≥ 24 px, or ≥ 18.66 px at w600/w700: 3:1 is enough.
  final bool large;

  /// A non-text graphic (a suit placeholder, an arrow, a ring): 3:1.
  final bool graphic;

  /// An inactive control at 40 %: exempt, listed so the omission is seen.
  final bool disabled;
}

/// A token nudged from the design's value against the surfaces it sits on.
class NudgedToken {
  const NudgedToken(this.name, this.token, this.design, this.surfaces);

  final String name;
  final Color token;
  final Color design;
  final List<Color> surfaces;
}

class Palette {
  const Palette._();

  /// The brand sheet's six swatches, exactly (#102).
  static const red = Color(0xFFC6483D);
  static const List<Color> brandSwatches = [
    teal,
    blue,
    violet,
    navy,
    red,
    cardFace,
  ];

  /// Inactive controls are dimmed to this, and marked disabled.
  static const double disabledOpacity = 0.4;

  // Brand and felt.
  static const navy = Color(0xFF05285F);
  static const feltTop = Color(0xFF0A3A80);
  static const feltMid = Color(0xFF05285F);
  static const feltBottom = Color(0xFF031634);
  static const teal = Color(0xFF00D6B4);
  static const blue = Color(0xFF0076F1);
  static const violet = Color(0xFF8448FC);

  /// The design's #7FA6D8, lightened one step to pass on the felt's
  /// brightest stop (#102).
  static const mist = Color(0xFF87ABDA);
  static const readout = Color(0xFF9FC3EE);
  static const card = Color(0xFF0B3670);
  static const cardDeep = Color(0xFF04213F);
  static const ink = Color(0xFF04213F);
  static const paleText = Color(0xFFDCE9F8);

  // Cards.
  static const cardFace = Color(0xFFF7F5EF);
  static const blackSuit = Color(0xFF16202B);

  /// The brand red darkened in its own hue until black-on-cream's
  /// neighbour passes 4.5:1 on the card face (#102; the design's #C6483D
  /// reads 4.38:1).
  static const redSuit = Color(0xFFC4453A);
  static const selectedRing = teal;
  static const hintRing = Color(0xFFFFC94A);
  static const faceEdge = Color(0x4D000000); // rgba(0,0,0,.30)
  static const backEdge = Color(0x47FFFFFF); // rgba(255,255,255,.28)
  static const cardShadow = Color(0x73000000); // rgba(0,0,0,.45)

  // Card backs: highlight, body, shade.
  static const navyBackHi = Color(0xFF2E6EE0);
  static const navyBack = Color(0xFF0E44A0);
  static const navyBackLo = Color(0xFF06265E);
  static const tealBackHi = Color(0xFF149C8D);
  static const tealBack = Color(0xFF0B615A);
  static const tealBackLo = Color(0xFF05332F);
  static const violetBackHi = Color(0xFF6B3ECB);
  static const violetBack = Color(0xFF3B2076);
  static const violetBackLo = Color(0xFF1E0F44);

  /// The mark's fourth stroke, the only colour of it not already a token.
  static const markDeepBlue = Color(0xFF0F3E86);

  static const backStripe = Color(0x17FFFFFF); // rgba(255,255,255,.09)
  static const backGlow = Color(0x1AFFFFFF); // rgba(255,255,255,.10)
  static const backInsetOuter = Color(0x24FFFFFF); // rgba(255,255,255,.14)
  static const backInsetInner = Color(0x12FFFFFF); // rgba(255,255,255,.07)

  // Text tokens (#102). The ones the design drew too dim are nudged; see
  // [nudges] for the design values.
  static const textBody = Color(0xFF8BACD1);
  static const textSoft = Color(0xFFBBD2EC);
  static const textBright = Color(0xFFC6DAF0);
  static const textViolet = Color(0xFFBB96FF);
  static const textBlue = Color(0xFF6FB4FF);
  static const amber = Color(0xFFFFB547);
  static const errorText = Color(0xFFFF9A90);
  static const textMuted = Color(0xFF93AACB);
  static const textFaint = Color(0xFF90AAC8);
  static const textKicker = Color(0xFF8FABD1);
  static const textAccentSoft = Color(0xFF06BDB3);
  static const textHint = Color(0xFF98A9C3);
  static const textOnTealSoft = Color(0xFF03535D);

  /// The empty foundation's suit placeholder: white at an alpha that reads
  /// 3:1 on the felt as a graphic.
  static const placeholderSuit = Color(0x9EFFFFFF);

  // Surfaces text sits on.
  static const panel = Color(0xFF122F63); // white 5 % over navy
  static const panelRaised = Color(0xFF16346A); // white 8 % over navy
  static const chip = Color(0xFF1A3A70); // white 12 % over navy
  static const tealFill = Color(0xFF0E3C6A); // teal 14 % over navy

  /// The felt's stops and the panels: what dim text sits on.
  static const List<Color> navySurfaces = [
    feltTop,
    navy,
    feltBottom,
    panel,
    panelRaised,
    card,
  ];

  /// Nudged tokens with their design values (#102).
  static const List<NudgedToken> nudges = [
    NudgedToken('textMuted', textMuted, Color(0xFF5C7FB0), navySurfaces),
    NudgedToken('textFaint', textFaint, Color(0xFF4E739F), navySurfaces),
    NudgedToken('textKicker', textKicker, Color(0xFF6E93C4), navySurfaces),
    NudgedToken('textBody', textBody, Color(0xFF87A9D0), navySurfaces),
    NudgedToken('mist', mist, Color(0xFF7FA6D8), navySurfaces),
    NudgedToken('textViolet', textViolet, Color(0xFFB48CFF), navySurfaces),
    NudgedToken('textBlue', textBlue, Color(0xFF6FB4FF), navySurfaces),
    NudgedToken('textSoft', textSoft, Color(0xFFBBD2EC), navySurfaces),
    NudgedToken('readout', readout, Color(0xFF9FC3EE), navySurfaces),
    NudgedToken(
      'textAccentSoft',
      textAccentSoft,
      Color(0xFF05A9A0),
      navySurfaces,
    ),
    NudgedToken('textHint', textHint, Color(0xFF7189AC), navySurfaces),
    NudgedToken('textOnTealSoft', textOnTealSoft, Color(0xFF035762), [teal]),
    NudgedToken('amber', amber, Color(0xFFFFB547), navySurfaces),
    NudgedToken('errorText', errorText, Color(0xFFFF9A90), navySurfaces),
    NudgedToken('redSuit', redSuit, red, [cardFace]),
  ];

  /// Every text colour on the surfaces it is drawn over, for the guard.
  static const List<TextPair> textPairs = [
    TextPair('body on navy', textBody, navySurfaces),
    TextPair('soft body', textSoft, navySurfaces),
    TextPair('bright body', textBright, navySurfaces),
    TextPair('mist meta', mist, navySurfaces),
    TextPair('readouts', readout, navySurfaces),
    TextPair('pale text', paleText, navySurfaces),
    TextPair('white text', Color(0xFFFFFFFF), [...navySurfaces, violet]),
    TextPair('muted labels', textMuted, navySurfaces),
    TextPair('faint version line', textFaint, navySurfaces),
    TextPair('kickers', textKicker, navySurfaces),
    TextPair('teal kickers and links', teal, navySurfaces),
    TextPair('soft teal notes', textAccentSoft, navySurfaces),
    TextPair('violet accents', textViolet, navySurfaces),
    TextPair('blue accents', textBlue, navySurfaces),
    TextPair('amber errors', amber, navySurfaces),
    TextPair('reset button text', errorText, navySurfaces),
    TextPair('ink on teal buttons', ink, [teal]),
    TextPair('soft ink on teal', textOnTealSoft, [teal]),
    TextPair('field hint', textHint, navySurfaces),
    TextPair('black suits', blackSuit, [cardFace]),
    TextPair('red suits', redSuit, [cardFace]),
    TextPair('empty-foundation suit', placeholderSuit, [
      feltTop,
      navy,
      feltBottom,
    ], graphic: true),
    TextPair('recycle arrow', readout, [
      feltTop,
      navy,
      feltBottom,
    ], graphic: true),
    TextPair('selection ring on the felt', selectedRing, [
      feltTop,
      navy,
      feltBottom,
    ], graphic: true),
    TextPair('hint ring on the felt', hintRing, [
      feltTop,
      navy,
      feltBottom,
    ], graphic: true),
    TextPair(
      'disabled controls at 40 %',
      Color(0x66DCE9F8),
      navySurfaces,
      disabled: true,
    ),
  ];
}
