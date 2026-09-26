/// A deal number: the seed a deal is generated from, shown to the player.
///
/// The number is the seed unchanged — options never mix into it — so the
/// same number in draw 1 and draw 3 lays out the same cards.
library;

import 'dart:math';

/// A positive int in 1..[DealNumber.max]. Construction outside the range
/// throws [ArgumentError].
extension type const DealNumber._(int value) {
  factory DealNumber(int value) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, 'value', 'must be in $min..$max');
    }
    return DealNumber._(value);
  }

  static const int min = 1;
  static const int max = 999999;

  /// A uniformly random deal number. This is the only place the engine
  /// touches an unseeded source: [source] defaults to `Random.secure()`.
  ///
  /// It lives outside every deal function so that dealing itself is always
  /// a pure function of the number.
  static DealNumber random([Random? source]) {
    final rng = source ?? Random.secure();
    return DealNumber._(min + rng.nextInt(max - min + 1));
  }

  /// The next number in the search order, wrapping from [max] to [min].
  DealNumber get next =>
      value == max ? const DealNumber._(min) : DealNumber._(value + 1);
}
