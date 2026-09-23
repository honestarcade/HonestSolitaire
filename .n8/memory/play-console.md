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
| Console app id | _(owner: fill in after runbook step 1)_ |
| developer account id | _(same developer account as Honest Sudoku)_ |

The package id is permanent from the moment it is typed on **Create app**.

## CI service account

| | |
|---|---|
| Cloud project | `honestsolitaire-ci` |
| service account | `honestsolitaire-ci@honestsolitaire-ci.iam.gserviceaccount.com` |
| Play permissions | Release to testing tracks; View app information and download bulk reports — nothing else |
| secret | `PLAY_SERVICE_ACCOUNT_JSON` |

## Constraints

- Personal developer account: production access needs a closed test with at
  least 12 testers opted in for 14 continuous days.
- `alpha` in the API is the Console's closed testing track.
- Until the first release is published, Play refuses a `completed` release on
  any track but `internal`; `tools/play_promote.sh` falls back to `draft` only
  on that exact refusal.

## Setup status

- 2026-09-23: upload keystore created (see [[android-signing]]). Runbook steps
  1–6 not yet done.
