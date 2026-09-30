// The host side of integration_test/perf_test.dart (#117): writes the
// device's report to the path tools/perf.sh names in PERF_OUT.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final out = File(
      Platform.environment['PERF_OUT'] ?? 'build/perf/perf.json',
    );
    await out.parent.create(recursive: true);
    await out.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
    stdout.writeln('PERF_REPORT ${out.path}');
  },
);
