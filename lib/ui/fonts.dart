/// The app's two typefaces (#96), bundled in `assets/fonts/` and never
/// fetched at run time (invariant 1). The theme's default family is Outfit;
/// styles the design sets in `'IBM Plex Mono'` use [AppFonts.plexMono] or
/// name [kFontMono]. `test/guards/fonts_test.dart` holds every weight the
/// code asks for to the weights the files carry.
library;

import 'package:flutter/painting.dart';

const String kFontOutfit = 'Outfit';
const String kFontMono = 'IBM Plex Mono';

class AppFonts {
  const AppFonts._();

  /// Outfit at [size]; weights 300–700 are bundled.
  static TextStyle outfit(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: kFontOutfit,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// IBM Plex Mono at [size]; weights 400–600 are bundled. Numbers that
  /// tick read better tabular, which a monospace face is by nature.
  static TextStyle plexMono(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: kFontMono,
    fontFamilyFallback: const ['monospace'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
