// The host side of integration_test/layout_sweep_test.dart (#114): saves
// each screenshot the device takes into the directory tools/layout.sh names
// in LAYOUT_OUT.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Directory(
      Platform.environment['LAYOUT_OUT'] ?? 'build/layout/screens',
    );
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
);
