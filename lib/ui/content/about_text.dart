/// The About screens' copy (#91): the design's words with two corrections
/// (owner, gate list): the No-accounts promise carries the Android-backup
/// qualifier, and the statistics line says what is split by mode.
library;

import 'package:flutter/painting.dart';

import '../theme/palette.dart';

const aboutIntro =
    'Two classics, done properly: Klondike with draw one or draw three, and '
    'Spider at one, two or four suits. Real shuffles, unlimited undo, honest '
    'statistics. Nothing is unlocked with money, because there is nothing to '
    'buy.';

class Feature {
  const Feature(this.title, this.text);

  final String title;
  final String text;
}

const features = [
  Feature(
    'Klondike, both draws',
    'Draw one or draw three, standard, Vegas or no scoring, unlimited passes.',
  ),
  Feature(
    'Spider, three difficulties',
    'One, two or four suits from a proper two-deck shuffle.',
  ),
  Feature(
    'Unlimited undo and hints',
    'Step back as far as you like; ask for the next legal move when you are '
        'stuck.',
  ),
  Feature(
    'Auto-finish and one-tap moves',
    'Skip the busywork once the outcome is decided.',
  ),
  Feature(
    'Honest statistics',
    'Wins, streaks, best times and fewest moves for each game; win rates '
        'split by draw mode and suit count.',
  ),
  Feature(
    'Three card backs',
    'Navy, teal and violet — all carrying the Honest Arcade mark.',
  ),
];

const promiseChips = [
  'NO ADS',
  'NO TRACKING',
  'NO ACCOUNTS',
  'NO PURCHASES',
  'NO PERMISSIONS',
  'OPEN SOURCE',
  'WORKS OFFLINE',
];

const studioParagraphs = [
  'Honest Arcade makes simple games and useful apps with no ads, no '
      'tracking, and no hidden agenda. Everything we build is open source, so '
      'you can see exactly what you\'re getting.',
  'Just good software that respects your time, privacy, and device.',
];

const supportText =
    'Our games stay free and ad-free because people chip in. If you\'d like '
    'to help keep them that way, visit the website for details.';

class Promise {
  const Promise(this.title, this.text, this.color);

  final String title;
  final String text;
  final Color color;
}

const _tealMark = Color(0xFF00D6B4);
const _blueMark = Palette.textBlue;
const _violetMark = Palette.textViolet;

const promises = [
  Promise(
    'No ads. Ever.',
    'No banners, no interstitials, no "watch a video to unlock". What you '
        'open is the whole thing.',
    _tealMark,
  ),
  Promise(
    'No tracking, no analytics',
    'We collect nothing. No identifiers, no crash pings, no usage events.',
    _blueMark,
  ),
  Promise(
    'No accounts, no sign-in',
    'Your progress stays on your device; the app never uploads it. If '
        'Android backup is on, Android may include it in your Google account '
        'backup — your setting, not ours.',
    _violetMark,
  ),
  Promise(
    'No in-app purchases',
    'Everything is included. Nothing is held back for money.',
    _tealMark,
  ),
  Promise(
    'No permissions',
    'We ask for nothing — no contacts, no location, no storage, no network '
        '(unless explicitly needed for the app to function).',
    _blueMark,
  ),
  Promise(
    'Open source',
    'The code is readable. Check how it works rather than taking our word '
        'for it.',
    _violetMark,
  ),
  Promise(
    'Works offline, stays small',
    'No background activity, no battery drain while you are not using it '
        '(unless being online is explicitly needed for the app to function).',
    _tealMark,
  ),
];
