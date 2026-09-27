/// Every duration the app's UI animates with, and the level that scales
/// them (#105). Motion is what the design shows and nothing more: a
/// cross-fade between screens, the pause and win cards rising in, the
/// Settings knob sliding. The Card animations setting off keeps the UI
/// fades but shortens them; the phone's remove-animations collapses every
/// one to an instant change (owner, round one).
library;

import 'package:flutter/widgets.dart';

import 'settings/play_settings.dart';

/// How much the app animates.
enum AppMotion {
  /// Everything as designed.
  full,

  /// Card animations off: no card motion, UI fades of [reducedFade].
  reduced,

  /// The phone removes animations: everything instant.
  none;

  /// The level for [settings] under this [context]'s MediaQuery.
  static AppMotion of(BuildContext context, PlaySettings settings) =>
      MediaQuery.disableAnimationsOf(context)
      ? AppMotion.none
      : settings.cardAnimations
      ? AppMotion.full
      : AppMotion.reduced;

  /// Whether the cards move at all.
  bool get cards => this == AppMotion.full;

  /// [design] at full, [reducedFade] when reduced, nothing when none.
  Duration ui(Duration design) => switch (this) {
    AppMotion.full => design,
    AppMotion.reduced => reducedFade,
    AppMotion.none => Duration.zero,
  };

  /// How long READY holds on the splash before its fade (#87).
  Duration get splashHold => switch (this) {
    AppMotion.full => splashHoldFull,
    AppMotion.reduced => splashHoldReduced,
    AppMotion.none => Duration.zero,
  };
}

/// The cross-fade between screens.
const Duration routeFade = Duration(milliseconds: 200);

/// The pause and win cards rising in (the design's `hs-rise`).
const Duration cardRise = Duration(milliseconds: 350);

/// The Settings switch's knob and track.
const Duration switchSlide = Duration(milliseconds: 150);

/// A banner appearing, and a scroll back to the top.
const Duration bannerFade = Duration(milliseconds: 150);

/// The splash's fade out.
const Duration splashFade = Duration(milliseconds: 200);

/// READY holds this long before the fade at full motion; less when reduced.
const Duration splashHoldFull = Duration(milliseconds: 350);
const Duration splashHoldReduced = Duration(milliseconds: 150);

/// Every UI fade under [AppMotion.reduced].
const Duration reducedFade = Duration(milliseconds: 100);

/// How far the cards rise, at the design width (390); scales with the
/// capped screen width.
const double riseDistance = 8;

/// The rise scales with min(width, 480) / 390.
double riseFor(double width) =>
    riseDistance * (width < 480 ? width : 480) / 390;

/// The screens' cross-fade.
const Curve routeCurve = Curves.easeInOut;

/// The cards' rise: the design's `ease-out`.
const Curve riseCurve = Cubic(0, 0, .58, 1);

/// The knob and the track colour.
const Curve switchCurve = Curves.easeOut;
