---
name: play-console
description: The Play Console app entry, the CI service account, and the constraints a personal developer account puts on getting to production
metadata:
  type: project
---

# Play Console (Honest Solitaire)

**Never store credentials here.** Identifiers and constraints only; secret
values live in the repository's Actions secrets and the owner's password
manager.

The click-by-click procedure is `play-console-runbook.md`; this file records
what it produced for this app.

## The app entry

| | |
|---|---|
| name | Honest Solitaire |
| package | `com.honestarcade.solitaire` |
| type | Game, free |
| default language | English (US) |
| Console app id | `4975858088283771554` |
| developer account id | `5264586118822775573` (same account as Honest Sudoku) |
| owner account | `ntpond@gmail.com` |

The package id is permanent from the moment it is typed on **Create app**.

## CI service account

| | |
|---|---|
| Cloud project | `honestsolitaire-ci` |
| service account | `honestsolitaire-ci@honestsolitaire-ci.iam.gserviceaccount.com` |
| Play permissions | Release to testing tracks; View app information and download bulk reports — nothing else |
| secret | `PLAY_SERVICE_ACCOUNT_JSON` |
| key id | `32606ad6c44c1638d37563534944474e9626346a` (public; needed to revoke the right key) |

## Constraints

- Personal developer account: production access needs a closed test with at
  least 12 testers opted in for 14 continuous days.
- `alpha` in the API is the Console's closed testing track.
- Until the first release is published, Play refuses a `completed` release on
  any track but `internal`; `tools/play_promote.sh` falls back to `draft` only
  on that exact refusal.

## Setup status

- 2026-09-23: upload keystore created (see [[android-signing]]).
- 2026-09-23: runbook steps 1–6 done. Owner created the app entry and invited
  the service account; `tools/setup_play_ci.sh` created the Cloud project and
  service account (the key-create step failed once with NOT_FOUND while the new
  account propagated, and passed on the idempotent re-run ~20 s later);
  `tools/set_ci_secrets.sh` set the four keystore secrets; `play-api-check`
  run 35935643708 passed both Play access and keystore steps. Issue #20.
- 2026-09-23: owner copied the keystore password to their password manager;
  `solitaire-signing-credentials.txt` deleted.
- 2026-09-24: `v0.1.0` (code 1011) uploaded to the internal track by release
  run 35937560222; this first upload enrolled Play App Signing with the
  committed upload certificate. Tagged with a bare `git tag`, so no GitHub
  release holds the bundle — it is in that run's artifact. Issue #21.
