/// The design's colour tokens (`Honest Solitaire.dc.html`, brand sheet and
/// board), in one place so every screen reads the same values.
library;

import 'package:flutter/painting.dart';

class Palette {
  const Palette._();

  // Brand and felt.
  static const navy = Color(0xFF05285F);
  static const feltTop = Color(0xFF0A3A80);
  static const feltMid = Color(0xFF05285F);
  static const feltBottom = Color(0xFF031634);
  static const teal = Color(0xFF00D6B4);
  static const blue = Color(0xFF0076F1);
  static const violet = Color(0xFF8448FC);
  static const mist = Color(0xFF7FA6D8);
  static const readout = Color(0xFF9FC3EE);
  static const card = Color(0xFF0B3670);
  static const cardDeep = Color(0xFF04213F);
  static const ink = Color(0xFF04213F);
  static const paleText = Color(0xFFDCE9F8);

  // Cards.
  static const cardFace = Color(0xFFF7F5EF);
  static const blackSuit = Color(0xFF16202B);
  static const redSuit = Color(0xFFC6483D);
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
}
