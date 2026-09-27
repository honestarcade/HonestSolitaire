/// Loads the bundled typefaces into a widget test (#96), so text metrics are
/// real instead of flutter_test's Ahem block font. Opt-in: only the tests
/// that measure text call it; everything else stays on Ahem.
library;

import 'dart:io';

import 'package:flutter/services.dart';

const _files = {
  'Outfit': [
    'Outfit-Light.ttf',
    'Outfit-Regular.ttf',
    'Outfit-Medium.ttf',
    'Outfit-SemiBold.ttf',
    'Outfit-Bold.ttf',
  ],
  'IBM Plex Mono': [
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Medium.ttf',
    'IBMPlexMono-SemiBold.ttf',
  ],
};

Future<void> loadAppFonts() async {
  for (final e in _files.entries) {
    final loader = FontLoader(e.key);
    for (final name in e.value) {
      final bytes = File('assets/fonts/$name').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}
