# Honest Solitaire

Klondike and Spider solitaire for Android phones, fully offline, built with
Flutter. No ads, no tracking, no accounts, no purchases, no permissions.

The project is under construction; gameplay and features are planned and
tracked as GitHub Issues. The infrastructure comes from
[android-studio-app-template](https://github.com/honestarcade/android-studio-app-template).

## Requirements

- Android 7.0 (API 24) or newer.
- Flutter (the exact version CI uses is in `.fvmrc`) and a JDK 17 or newer for
  the Gradle build.

## Build and run

```sh
flutter pub get
flutter run                        # a connected Android device or emulator
flutter build appbundle --debug    # the Android App Bundle
```

## Quality gate

One command runs everything CI runs, in the order CI runs it:

```sh
tools/gate.sh
```

Six steps, stopping at the first failure: resolve dependencies against the
lockfile, analyze (infos are fatal), check formatting, run the tests including
the invariant guards, build the release bundle, and scan that bundle for
Android permissions. It reports rather than rewrites — a formatting failure
names the file and leaves it alone.

CI runs one more job, `tools/mutation_check.py`: it reintroduces each known
defect in turn and requires the guard suite to catch it. See `CLAUDE.md`.

The **CI** workflow (`.github/workflows/ci.yml`, job `gate`) runs this same
script on every pull request, so green locally and green in CI mean the same
thing.

**Signing.** The four variables are `HS_KEYSTORE_PATH`, `HS_KEYSTORE_PASS`,
`HS_KEY_ALIAS` and `HS_KEY_PASS`. Set all four to sign with the upload key; set
none and the release build falls back to the debug key, so the gate passes on
a fresh clone with no secrets. Setting some but not all is refused.
`HS_RELEASE=1` makes a missing signing input a hard failure instead of the
fallback — that is how CI proves a release is really signed. Verify a built
bundle against the committed certificate with `tools/verify_upload_cert.sh`;
the certificate's alias and fingerprint are in `android/signing/README.md`.

## Release

A release is a tag. Nothing is published by hand.

```sh
git tag v0.1.0 && git push origin v0.1.0
```

`.github/workflows/release.yml` triggers on any `v*` tag. It re-runs the whole
PR gate first, then builds a signed bundle, scans it for Android permissions,
checks it against the committed upload certificate, attaches it to the GitHub
release if one exists for the tag (`/n8-release` creates the two together; a
bare `git tag` leaves the bundle in the run's artifacts only), and uploads it to
the Play **internal** track. The Play upload is the
last step, so a failure anywhere earlier ships nothing.

**Never re-tag a version that shipped; ship the next one.** Play will not
accept a version code it has already seen. `tools/ci_version.sh` derives the
version name from the tag and the code from the run number and attempt.

**Promotion** is a separate manual workflow, `.github/workflows/play-promote.yml`,
which moves the newest release between testing tracks and refuses
`production`. Production is a human act in the Play Console.

**The five secrets** the release path reads, all repository secrets:

| Secret | What it holds |
|---|---|
| `HS_KEYSTORE_B64` | the upload keystore, base64 on one line |
| `HS_KEYSTORE_PASS` | the keystore password |
| `HS_KEY_ALIAS` | the key alias inside the keystore (`upload`) |
| `HS_KEY_PASS` | the key password — **must equal `HS_KEYSTORE_PASS`** |
| `PLAY_SERVICE_ACCOUNT_JSON` | the Play Developer API service-account key |

They are set by script, never by hand: `tools/setup_play_ci.sh` creates the
service account and sets the last one; `tools/set_ci_secrets.sh` sets the
other four from the local credentials file. `.github/workflows/play-api-check.yml`
is a manual dispatch that proves the secrets work without publishing anything.
The Console side is `.n8/memory/play-console-runbook.md`.

## Privacy

The app collects nothing and has no network access: the release build requests
no Android permissions at all, INTERNET included. The policy is published at
<https://honestarcade.github.io/HonestSolitaire/privacy> and lives in this
repository at `docs/privacy.md` — everything under `docs/` is public.

## License

**MIT** (see `LICENSE`) — covering the source code and the art. Use it, learn
from it, ship your own.

Two things are held back, because they are not ours to give away:

**Audio.** When licensed sound effects ship, they will not be covered by the
MIT licence, and their provenance will be recorded in an audio licence file
beside them.

**Names and logos.** "Honest Arcade", "Honest Solitaire", the four-corner
outline mark shared across the studio's apps, and the launcher icons built from
it are trademarks of Honest Arcade. Fork the game freely, but ship it under
your own name and mark.

## Security

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.
