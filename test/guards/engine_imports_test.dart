@Tags(['guard'])
library;

// The engine stays pure Dart (#59).
//
// `lib/engine/` is testable without a Flutter binding and runnable in an
// isolate only while nothing under it imports Flutter, `dart:io`, `dart:ui`
// or any package. This guard reads every file there and refuses any
// directive outside the allowed set. The rule is proven both ways on inline
// fixtures, then applied to the real directory.
//
// What this does not cover: a directive hidden by a shape the comment
// stripper does not know (see CLAUDE.md on deliberate evasion), and code
// that reaches a platform through `dart:isolate` messages — the guard is
// about imports, not behaviour.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repo_files.dart';

/// The `dart:` libraries the engine may use. Everything else — `dart:io`,
/// `dart:ui`, `dart:html` — reaches a platform.
const allowedDartLibraries = {
  'dart:core',
  'dart:math',
  'dart:collection',
  'dart:convert',
  'dart:async',
  'dart:isolate',
};

const engineDir = 'lib/engine';

/// Removes `//` and `/* */` comments so a commented-out import is not an
/// offender. String literals are left alone: a directive's URI is one.
String stripDartComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

final _directive = RegExp(
  '''^\\s*(import|export|part)\\s+(?:of\\s+)?['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Normalises `a/./b/../c` to `a/c`; a `..` that climbs above the root
/// leaves a leading `..` so the caller can see the escape.
String _normalise(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..' && out.isNotEmpty && out.last != '..') {
      out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

/// The directives in [source] (a file at repository-relative [filePath])
/// that reach outside the engine: `package:` anything, a `dart:` library
/// outside [allowedDartLibraries], or a relative path that leaves
/// [engineDir]. `part of` with a library name (no URI) is ignored.
List<String> engineImportOffenders(String filePath, String source) {
  final offenders = <String>[];
  final dir = filePath.substring(0, filePath.lastIndexOf('/'));
  for (final match in _directive.allMatches(stripDartComments(source))) {
    final uri = match.group(2)!;
    if (uri.startsWith('dart:')) {
      if (!allowedDartLibraries.contains(uri)) offenders.add(uri);
    } else if (uri.contains(':') || uri.startsWith('/')) {
      offenders.add(uri);
    } else {
      final resolved = _normalise('$dir/$uri');
      if (!resolved.startsWith('$engineDir/')) offenders.add(uri);
    }
  }
  return offenders;
}

/// Every offender across the real engine directory, as `path: uri` lines.
List<String> realEngineOffenders() {
  final files = filesUnder(engineDir).where((p) => p.endsWith('.dart'));
  return [
    for (final path in files)
      for (final uri in engineImportOffenders(path, readFile(path)))
        '$path: $uri',
  ];
}

void main() {
  group('the rule itself, proven both ways', () {
    test('an engine file importing only allowed libraries passes', () {
      const source = '''
import 'dart:math';
import 'dart:collection';
import 'card.dart';
import './rng.dart';
export 'deck.dart';
part 'klondike_moves.dart';
''';
      expect(
        engineImportOffenders('lib/engine/klondike.dart', source),
        isEmpty,
      );
    });

    test('a Flutter import is reported', () {
      const source = '''
import 'package:flutter/foundation.dart';
import 'card.dart';
''';
      expect(engineImportOffenders('lib/engine/card.dart', source), [
        'package:flutter/foundation.dart',
      ]);
    });

    test('dart:io and dart:ui are reported; a commented import is not', () {
      const source = '''
import 'dart:io';
// import 'package:flutter/material.dart';
/* import 'dart:html'; */
import 'dart:ui' as ui;
''';
      expect(engineImportOffenders('lib/engine/x.dart', source), [
        'dart:io',
        'dart:ui',
      ]);
    });

    test('a relative import that leaves lib/engine is reported', () {
      const source = '''
import '../main.dart';
import 'sub/../card.dart';
''';
      expect(engineImportOffenders('lib/engine/x.dart', source), [
        '../main.dart',
      ]);
    });

    test('a self-package import is reported like any package', () {
      const source = "import 'package:honest_solitaire/engine/card.dart';";
      expect(engineImportOffenders('lib/engine/x.dart', source), hasLength(1));
    });
  });

  group('the real engine', () {
    test('lib/engine exists', () {
      expect(
        Directory('${repoRoot.path}/$engineDir').existsSync(),
        isTrue,
        reason:
            'engine-imports: $engineDir is missing — the guard has nothing '
            'to read, which is a failure, not a pass',
      );
    });

    test('lib/engine imports nothing outside dart:core/math/collection/'
        'convert/async/isolate and itself', () {
      final offenders = realEngineOffenders();
      expect(
        offenders,
        isEmpty,
        reason: describeOffenders('engine-imports', offenders),
      );
    });
  });
}
