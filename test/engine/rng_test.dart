import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/engine/rng.dart';

void main() {
  test('seed 1 produces the pinned first ten outputs', () {
    // Reference: the design prototype's JavaScript mulberry32 (`rnd` in
    // `Honest Solitaire.dc.html`) with its final division removed, run under
    // node v24.15.0 on 2026-09-26:
    //   function rnd(seed){let a=seed>>>0;return()=>{a=(a+0x6D2B79F5)>>>0;
    //   let t=Math.imul(a^a>>>15,1|a);t=(t+Math.imul(t^t>>>7,61|t))^t;
    //   return((t^t>>>14)>>>0)};}
    final rng = Rng(1);
    expect(List.generate(10, (_) => rng.nextUint32()), [
      2693262067,
      11749833,
      2265367787,
      4213581821,
      4159151403,
      1207330352,
      2632122864,
      3095568220,
      1828783984,
      4272732017,
    ]);
    final seven = Rng(7);
    expect(List.generate(3, (_) => seven.nextUint32()), [
      50271532,
      266108690,
      4195786334,
    ]);
  });

  test('the same seed gives the same 1000-long sequence', () {
    final a = Rng(7);
    final b = Rng(7);
    expect(
      List.generate(1000, (_) => a.nextUint32()),
      List.generate(1000, (_) => b.nextUint32()),
    );
  });

  test('different seeds differ', () {
    final a = Rng(7);
    final b = Rng(8);
    expect(
      List.generate(100, (_) => a.nextUint32()),
      isNot(List.generate(100, (_) => b.nextUint32())),
    );
  });

  test('outputs are unsigned 32-bit', () {
    final rng = Rng(123456);
    for (var i = 0; i < 10000; i++) {
      final x = rng.nextUint32();
      expect(x, inInclusiveRange(0, 0xFFFFFFFF));
    }
  });

  test('nextInt stays in range and rejects a non-positive bound', () {
    final rng = Rng(3);
    for (var i = 0; i < 10000; i++) {
      expect(rng.nextInt(7), inInclusiveRange(0, 6));
    }
    expect(() => rng.nextInt(0), throwsArgumentError);
  });

  test('shuffle returns a permutation and leaves the input alone', () {
    final input = List.generate(52, (i) => i);
    final copy = List.of(input);
    final out = shuffle(input, Rng(1));
    expect(input, copy);
    expect(out, isNot(input));
    expect(List.of(out)..sort(), input);
    expect(shuffle(input, Rng(1)), out);
  });

  test('a seed wider than 32 bits is masked', () {
    final a = Rng(0x1_0000_0005);
    final b = Rng(5);
    expect(a.nextUint32(), b.nextUint32());
  });
}
