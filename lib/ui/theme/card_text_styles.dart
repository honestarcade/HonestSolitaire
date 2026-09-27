/// The card's text styles — one point to swap in Outfit when M5 bundles it.
library;

import 'package:flutter/painting.dart';

import '../fonts.dart';

class CardTextStyles {
  const CardTextStyles._();

  /// The rank: bold, tight, no line-height slack (the design's
  /// `font:700 …/1`, `letter-spacing:-.05em`).
  static TextStyle rank(double size, Color color) => TextStyle(
    fontFamily: kFontOutfit,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.05 * size,
    color: color,
    decoration: TextDecoration.none,
  );
}
