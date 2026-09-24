---
name: android-signing
description: Where the Android upload keystore lives, how builds consume it, and how to rotate it
metadata:
  type: project
---

# Android upload signing

- **Keystore:** `~/HonestArcadeApps/secrets/solitaire-upload.keystore` —
  outside the repository, chmod 600. PKCS12, alias `upload`, RSA 2048,
  dname `O=Honest Arcade, CN=Honest Solitaire`. Created 2026-09-23 by
  `tools/make_upload_key.sh` with a randomly generated password.
- **Password:** in the owner's password manager, and in the `HS_KEYSTORE_PASS`
  / `HS_KEY_PASS` repository secrets. The credentials file the script wrote was
  deleted on 2026-09-23 after `tools/set_ci_secrets.sh` ran; to run that script
  again, recreate it from the password manager. PKCS12 has one password, so
  `HS_KEY_PASS` equals `HS_KEYSTORE_PASS`.
- **Certificate:** committed at `android/signing/upload_certificate.pem`; the
  fingerprint is in `android/signing/README.md`.
- **Build consumption:** `android/app/build.gradle.kts` reads
  `HS_KEYSTORE_PATH`, `HS_KEYSTORE_PASS`, `HS_KEY_ALIAS`, `HS_KEY_PASS` from the
  environment. There is no `key.properties`.
  - all four set → signed with the upload key
  - none set, `HS_RELEASE` unset → debug key, with a warning printed
  - `HS_RELEASE=1` and any missing → configuration fails naming the variable
  - partly set, in any mode → configuration fails
- **CI secret names:** `HS_KEYSTORE_B64`, `HS_KEYSTORE_PASS`, `HS_KEY_ALIAS`,
  `HS_KEY_PASS`, plus `PLAY_SERVICE_ACCOUNT_JSON`.

## Never regenerate silently

Once Play App Signing is enrolled at the first upload, this certificate **is**
the app's identity. If the keystore or its password is lost after enrolment,
do not re-run `make_upload_key.sh` (it refuses to overwrite anyway); use the
Play Console's upload-key reset under *Test and release → Play Store
protection* (the location Honest Sudoku's memory recorded on 2026-09-22).

Before enrolment, regenerating is harmless: move all three outputs aside
(keystore, credentials file, committed PEM) and re-run the script.
