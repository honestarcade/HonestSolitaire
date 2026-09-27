// The launcher-icon rules (#97), as pure functions over bytes and text.
// Ported from Honest Sudoku's launcher_icon_rules.dart (its #54), with the
// template-icon recognition, the start-screen mark and the safe-zone
// arithmetic added.
library;

import 'dart:math' as math;

/// A PNG's width, height and colour type, read from its signature and IHDR
/// by hand; null when [bytes] is not a PNG.
({int width, int height, int colorType})? pngHeader(List<int> bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 26) return null;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  if (String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') return null;
  int u32(int at) =>
      bytes[at] << 24 |
      bytes[at + 1] << 16 |
      bytes[at + 2] << 8 |
      bytes[at + 3];
  return (width: u32(16), height: u32(20), colorType: bytes[25]);
}

const res = 'android/app/src/main/res';

/// Every raster the icon and the start screen need, with its exact pixel
/// size.
const Map<String, int> kIconPngs = {
  '$res/mipmap-mdpi/ic_launcher_foreground.png': 108,
  '$res/mipmap-hdpi/ic_launcher_foreground.png': 162,
  '$res/mipmap-xhdpi/ic_launcher_foreground.png': 216,
  '$res/mipmap-xxhdpi/ic_launcher_foreground.png': 324,
  '$res/mipmap-xxxhdpi/ic_launcher_foreground.png': 432,
  '$res/mipmap-mdpi/ic_launcher_monochrome.png': 108,
  '$res/mipmap-hdpi/ic_launcher_monochrome.png': 162,
  '$res/mipmap-xhdpi/ic_launcher_monochrome.png': 216,
  '$res/mipmap-xxhdpi/ic_launcher_monochrome.png': 324,
  '$res/mipmap-xxxhdpi/ic_launcher_monochrome.png': 432,
  '$res/mipmap-mdpi/ic_launcher.png': 48,
  '$res/mipmap-hdpi/ic_launcher.png': 72,
  '$res/mipmap-xhdpi/ic_launcher.png': 96,
  '$res/mipmap-xxhdpi/ic_launcher.png': 144,
  '$res/mipmap-xxxhdpi/ic_launcher.png': 192,
  '$res/drawable-mdpi/launch_mark.png': 96,
  '$res/drawable-hdpi/launch_mark.png': 144,
  '$res/drawable-xhdpi/launch_mark.png': 192,
  '$res/drawable-xxhdpi/launch_mark.png': 288,
  '$res/drawable-xxxhdpi/launch_mark.png': 384,
  'ArtSource/store/icon-512.png': 512,
};

/// `path: problem` for each raster in [files] (path → bytes, null when
/// missing) that is absent, the wrong size, or not RGBA.
List<String> pngOffenders(Map<String, List<int>?> files) => [
  for (final MapEntry(key: path, value: size) in kIconPngs.entries)
    ...() {
      final bytes = files[path];
      if (bytes == null) return ['$path: missing'];
      final h = pngHeader(bytes);
      if (h == null) return ['$path: not a PNG'];
      return [
        if (h.width != size || h.height != size)
          '$path: ${h.width}×${h.height}, not $size×$size',
        if (h.colorType != 6) '$path: colour type ${h.colorType}, not RGBA (6)',
      ];
    }(),
];

/// FNV-1a over [bytes], 64-bit: enough to recognise a known file.
int fnv1a64(List<int> bytes) {
  var h = 0xcbf29ce484222325;
  for (final b in bytes) {
    h ^= b;
    h = (h * 0x100000001b3).toUnsigned(64);
  }
  return h;
}

/// The template's default Flutter launcher icons by density: length and
/// FNV-1a 64 of each `ic_launcher.png` in android-studio-app-template at
/// 4f43e95 (2026-09-23), computed 2026-09-26 with python3 for #97. A wrong
/// but non-default image is not recognised — this catches the template
/// surviving, nothing else.
const Map<String, (int, int)> kTemplateIcons = {
  'mdpi': (442, 0xcc80822407dd8469),
  'hdpi': (544, 0x8c1ddfe1f8e95521),
  'xhdpi': (721, 0xb50bf20408c675bb),
  'xxhdpi': (1031, 0x54e861a18f6f9c34),
  'xxxhdpi': (1443, 0x25b98cf0ac669cff),
};

/// The densities whose `ic_launcher.png` in [files] (density → bytes) is the
/// template's default icon.
List<String> templateIconOffenders(Map<String, List<int>> files) => [
  for (final e in files.entries)
    if (kTemplateIcons[e.key] case final t?
        when t.$1 == e.value.length && t.$2 == fnv1a64(e.value))
      '${e.key}: ic_launcher.png is the template\'s default Flutter icon',
];

/// What the adaptive icon XML lacks of its three layers.
List<String> adaptiveIconOffenders(String xml) => [
  for (final (layer, ref) in [
    ('background', '@color/ic_launcher_background'),
    ('foreground', '@mipmap/ic_launcher_foreground'),
    ('monochrome', '@mipmap/ic_launcher_monochrome'),
  ])
    if (!RegExp('<$layer\\s+android:drawable="${RegExp.escape(ref)}"\\s*/>')
        .hasMatch(xml))
      'no <$layer android:drawable="$ref"/>',
];

/// What an Android 12+ styles file lacks: the launch theme's splash is navy
/// and shows the mark.
List<String> splashOffenders(String xml) {
  const navy = r'(@color/launch_navy|#FF05285F|#05285F)';
  final theme = RegExp(
    r'<style name="LaunchTheme"[^>]*>(.*?)</style>',
    dotAll: true,
  ).firstMatch(xml)?[1];
  if (theme == null) return ['no LaunchTheme'];
  return [
    if (!RegExp(
      '<item name="android:windowSplashScreenBackground">$navy</item>',
    ).hasMatch(theme))
      'LaunchTheme has no navy windowSplashScreenBackground',
    if (!theme.contains(
      '<item name="android:windowSplashScreenAnimatedIcon">'
      '@mipmap/ic_launcher_foreground</item>',
    ))
      'LaunchTheme has no windowSplashScreenAnimatedIcon of the mark',
  ];
}

/// What a pre-12 launch_background.xml lacks: navy under the centred mark.
List<String> launchBackgroundOffenders(String xml) => [
  if (!xml.contains('@color/launch_navy')) 'no @color/launch_navy layer',
  if (!RegExp(
    r'<bitmap\s+android:gravity="center"\s+android:src="@drawable/launch_mark"',
  ).hasMatch(xml))
    'no centred @drawable/launch_mark bitmap',
];

/// The four corner paths of an SVG's corner group: (stroke, d) with the
/// path data's whitespace normalised.
List<(String, String)> cornerPaths(String svg) {
  final group = RegExp(
    r'<g fill="none" stroke-width="6" stroke-linecap="round" '
    r'stroke-linejoin="round">(.*?)</g>',
    dotAll: true,
  ).firstMatch(svg);
  if (group == null) return const [];
  return [
    for (final m in RegExp(
      r'<path stroke="(#[0-9A-Fa-f]{6})" d="([^"]*)"',
    ).allMatches(group[1]!))
      (m[1]!.toUpperCase(), m[2]!.trim().replaceAll(RegExp(r'\s+'), ' ')),
  ];
}

/// How [svg]'s corner group differs from the studio mark's; with
/// [colours] false only the geometry is compared (the monochrome layer).
List<String> cornerOffenders(String svg, String studio, {bool colours = true}) {
  final got = cornerPaths(svg);
  final want = cornerPaths(studio);
  if (want.length != 4) return ['the studio mark has ${want.length} corners'];
  if (got.length != 4) return ['${got.length} corner paths, not 4'];
  return [
    for (var i = 0; i < 4; i++) ...[
      if (got[i].$2 != want[i].$2)
        'corner ${i + 1} is "${got[i].$2}", not "${want[i].$2}"',
      if (colours && got[i].$1 != want[i].$1)
        'corner ${i + 1} is ${got[i].$1}, not ${want[i].$1}',
    ],
  ];
}

/// The mark block between `mark:begin` and `mark:end`, each line stripped
/// of its indentation; null when absent.
String? inlineMark(String svg) {
  final m = RegExp(
    r'<!-- mark:begin -->(.*?)<!-- mark:end -->',
    dotAll: true,
  ).firstMatch(svg);
  return m?[1]!.split('\n').map((l) => l.trim()).join('\n').trim();
}

/// The `0xFF......` value assigned to [identifier] in Dart [source].
String? dartHex(String source, String identifier) =>
    RegExp('\\b$identifier\\b[^;]*?0x[Ff]{2}([0-9A-Fa-f]{6})')
        .firstMatch(source)?[1]
        ?.toUpperCase();

/// The `#FF......` value of Android colour [name] in colors.xml [xml].
String? androidColor(String xml, String name) =>
    RegExp('<color name="$name">#(?:FF)?([0-9A-Fa-f]{6})</color>')
        .firstMatch(xml)?[1]
        ?.toUpperCase();

/// How far, in dp, the mark's farthest point sits from the centre of a
/// 108-dp adaptive-icon layer, read from [foregroundSvg]'s transform and
/// its first corner: the corner's outer edge is an arc of radius r + half
/// the stroke about the arc centre, and its farthest point from the box
/// centre lies on the diagonal. Null when the file cannot be read that way.
double? safeZoneReachDp(String foregroundSvg) {
  final tr = RegExp(
    r'transform="translate\(([\d.]+),\s*([\d.]+)\)\s+scale\(([\d.]+)\)"',
  ).firstMatch(foregroundSvg);
  final view = RegExp(r'viewBox="0 0 (\d+) \d+"').firstMatch(foregroundSvg);
  final corner = cornerPaths(foregroundSvg);
  final stroke = RegExp(r'stroke-width="([\d.]+)"').firstMatch(foregroundSvg);
  if (tr == null || view == null || corner.isEmpty || stroke == null) {
    return null;
  }
  final d = RegExp(
    r'M ([\d.]+) ([\d.]+) L [\d.]+ ([\d.]+) A ([\d.]+) [\d.]+ 0 0 [01] ([\d.]+) [\d.]+',
  ).firstMatch(corner.first.$2);
  if (d == null) return null;
  final x0 = double.parse(d[1]!);
  final yMid = double.parse(d[3]!);
  final r = double.parse(d[4]!);
  final xMid = double.parse(d[5]!);
  // The arc centre is (xMid, yMid); the box is 64 units, centred at 32.
  final outer = r + double.parse(stroke[1]!) / 2;
  final reachUnits =
      (32 - (math.min(xMid, yMid) - outer / math.sqrt2)) * math.sqrt2;
  final scale = double.parse(tr[3]!);
  final px = reachUnits * scale;
  final layer = double.parse(view[1]!);
  // Sanity: the box must be centred, or the arithmetic above is not about
  // this file.
  final translate = double.parse(tr[1]!);
  if ((translate * 2 + 64 * scale - layer).abs() > 0.01 || x0 != 3) {
    return null;
  }
  return px / (layer / 108);
}
