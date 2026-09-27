// Runs before every test file (flutter_test finds it by name).
//
// Card animations (#99) are off for every test by default, through the
// phone's own switch: `MediaQuery.disableAnimations`. The M3/M4 suites read
// a card's rect right after a move and tap it, which only holds when the
// board snaps. The tests that are about motion opt back in with
// `tester.platformDispatcher.accessibilityFeaturesTestValue`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  await testMain();
}
