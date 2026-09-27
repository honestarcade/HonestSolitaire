/// The card back styles and ring states the board asks for.
library;

import 'package:flutter/painting.dart';

import '../theme/palette.dart';

enum CardBack {
  navy(Palette.navyBackHi, Palette.navyBack, Palette.navyBackLo, 'Navy'),
  teal(Palette.tealBackHi, Palette.tealBack, Palette.tealBackLo, 'Teal'),
  violet(
    Palette.violetBackHi,
    Palette.violetBack,
    Palette.violetBackLo,
    'Violet',
  );

  const CardBack(this.highlight, this.body, this.shade, this.label);

  final Color highlight;
  final Color body;
  final Color shade;
  final String label;
}

enum CardRing { none, selected, hinted }
