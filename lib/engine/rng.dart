/// A seeded 32-bit generator the engine owns, so a deal number produces the
/// same shuffle on every device and every SDK release. `dart:math`'s `Random`
/// promises no particular sequence, which is why it is not used here.
///
/// The algorithm is mulberry32, the one the design's prototype shuffles with.
library;

/// mulberry32 over a 32-bit state. Outputs are unsigned 32-bit ints.
class Rng {
  /// The seed is masked to 32 bits and used unchanged (deal numbers are never
  /// zero, and a zero seed is a valid mulberry32 state anyway).
  Rng(int seed) : _state = seed & _mask32;

  static const int _mask32 = 0xFFFFFFFF;
  static const int _two32 = 0x100000000;

  int _state;

  /// The next output, 0 <= n < 2^32.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask32;
    var t = _imul(_state ^ (_state >>> 15), 1 | _state);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) ^ t) & _mask32;
    return (t ^ (t >>> 14)) & _mask32;
  }

  /// An unbiased integer in 0 <= n < [bound], by rejection sampling.
  int nextInt(int bound) {
    if (bound <= 0) throw ArgumentError.value(bound, 'bound', 'must be > 0');
    final limit = _two32 - (_two32 % bound);
    while (true) {
      final x = nextUint32();
      if (x < limit) return x % bound;
    }
  }

  /// A double in [0, 1), from one 32-bit output.
  double nextDouble() => nextUint32() / _two32;
}

/// The low 32 bits of `a * b`, computed from 16-bit halves so the result is
/// exact on the VM and on the web's 53-bit integers alike.
int _imul(int a, int b) {
  final aHigh = (a >>> 16) & 0xFFFF;
  final aLow = a & 0xFFFF;
  final bHigh = (b >>> 16) & 0xFFFF;
  final bLow = b & 0xFFFF;
  return (aLow * bLow + (((aHigh * bLow + aLow * bHigh) & 0xFFFF) << 16)) &
      0xFFFFFFFF;
}

/// Fisher–Yates from the last index down, driven only by [rng]. Returns a new
/// list; [items] is not changed.
List<T> shuffle<T>(List<T> items, Rng rng) {
  final out = List<T>.of(items);
  for (var i = out.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}
