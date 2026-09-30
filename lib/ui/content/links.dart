/// The links the About screens open in the phone's browser (#91). The app
/// itself never gains network access; the platform channel hands the URL to
/// Android.
library;

class Link {
  const Link(this.name, this.url, this.display);

  /// For keys: `about-link-<name>`.
  final String name;
  final String url;

  /// The form shown in messages ("honestarcade.app/contribute").
  final String display;
}

const siteLink = Link('site', 'https://honestarcade.app', 'honestarcade.app');
const contributeLink = Link(
  'contribute',
  'https://honestarcade.app/contribute',
  'honestarcade.app/contribute',
);

/// About the App's source link: this app's repository (owner, round one).
const appSourceLink = Link(
  'source',
  'https://github.com/honestarcade/HonestSolitaire',
  'github.com/honestarcade/HonestSolitaire',
);

/// About Honest Arcade's source link: this app's repository too (owner,
/// 2026-09-29 device play-through, #153 — it was the studio page).
const studioSourceLink = Link(
  'source',
  'https://github.com/honestarcade/HonestSolitaire',
  'github.com/honestarcade/HonestSolitaire',
);
