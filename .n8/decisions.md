# Decisions

A dated, append-only narrative of choices made during planning and execution
-- not a source of current counts or facts. If a sentence here would state a
number or a status that a command could compute, prefer the command; a
narrative entry is a record of *why*, not a live dashboard. (This project's
own history is the cautionary tale: five consecutive passes over Honest
Sudoku's decisions.md each corrected a stale count and shipped a new one.
See CLAUDE.md's note on the same rule.)

Entries are appended by `/n8-exec`, `/n8-replan`, and any session that makes
a decision outside those commands (a project's `CLAUDE.md` should carry the
standing instruction to log here; `/n8-init` writes it).

Format:

```markdown
## /n8-exec M1 -- 2026-08-27

- **Decision:** <what was chosen>
  **Why:** <the reasoning>
  **Issue:** <#N>
```

Ad-hoc entries (decisions made outside a planning/execution command) use:

```markdown
## Ad-hoc -- 2026-08-27

- **Change:** <what changed>
  **Why:** <the reasoning>
  **Affects:** <milestones/issues likely affected>
```

## /n8-init + M0/M1 scaffold -- 2026-09-23

- **Decision:** Package id `com.honestarcade.solitaire`, Dart package `honest_solitaire`, app slug `solitaire` (keystore files) and `honestsolitaire` (Cloud project `honestsolitaire-ci`), minSdk 24, portrait only.
  **Why:** Follows Honest Sudoku's naming (`com.honestarcade.sudoku`, `honestsudoku-ci`) so the studio's apps read alike; owner may still change the package id before runbook step 1, after which it is permanent.
  **Issue:** M0 epic
- **Decision:** The package id is written literally into `tools/check_aab.sh` and all four workflows instead of the template's `vars.APP_PACKAGE_ID` fallback.
  **Why:** Removes an owner step (setting a repo variable) and a failure mode (an unset variable uploads to the template's placeholder id).
  **Issue:** M1 epic
- **Decision:** Upload keystore generated now, with a random password, rather than left for the owner.
  **Why:** Before Play enrolment regeneration is harmless, and generating it lets M0 commit the certificate and prove the signed build locally. The owner only has to move the password into a password manager.
  **Issue:** M0 epic
- **Decision:** Four invariants: no network/permissions, lean dependencies, deterministic on-device deals, honest "winnable deals only".
  **Why:** The first two come from the studio promises and are guarded by the template's guards today; the last two are the Solitaire counterparts of Sudoku's generation invariants, and their guards are M2's to write.
  **Issue:** CLAUDE.md
- **Decision:** `lib/main.dart` is a branded placeholder screen, not the design's splash.
  **Why:** M0/M1 deliver infrastructure; screens belong to later milestones, planned from the design by `/n8-plan`.
  **Issue:** M0 epic

## Ad-hoc -- 2026-09-23

- **Change:** The first real run of the promote workflow (internal → closed testing, #22) moved from M1 to M7.
  **Why:** Owner: there is nothing to test yet. The workflow and `tools/play_promote.sh` still ship in M1 from the template; only their proof moves to when the closed test starts.
  **Affects:** M1 (epic #2 no longer needs a promotion to close; its AC is annotated), M7 (epic #10 gains the first promotion ahead of the 12-tester closed test).

## /n8-exec M0 (verification fix pass) -- 2026-09-24

- **Decision:** Ran the fix pass on `milestone/m0-fixes` for the seven M0 bugs /n8-verify filed (#28–#34); #29 and #30 share one commit because both change `tools/check_aab.sh`'s package check and are proven by the same fixtures.
  **Why:** One branch per milestone; the two stories are inseparable in that file.
  **Issue:** #29, #30
- **Decision:** `check_aab.sh` now checks the package id first and exits 2 before the permission scan.
  **Why:** The self-permission allowlist is derived from the package, so a wrong id surfaced as bogus PERMISSION lines and exit 1 (Rule 1 fix). A wrong-package bundle that also requests a permission now reports only the package; fixing the package re-exposes the permission on the next run.
  **Issue:** #29
- **Decision:** Bundle-scan fixtures are synthetic zips of NUL-separated strings shaped like the protobuf manifest's readable runs, not byte-edited copies of a real build.
  **Why:** The guard suite must not need a Flutter build; the shapes were taken from the real v0.1.0 manifest (`unzip -p … | tr -c '[:print:]' '\n'`). Short names carry no printable length byte, which the first fixture draft got wrong.
  **Issue:** #30
- **Decision:** The dependency guard reads keys with `package:yaml` and each key's own text line for its `# why:`; a key whose line cannot be found counts as unjustified.
  **Why:** Comments are dropped by the parser, so justification still needs the text; failing closed on an unfindable line keeps a new YAML shape from becoming a bypass.
  **Issue:** #32
- **Decision:** Two history notes in `tools/mutation_check.py` now say they describe Honest Sudoku's `signing_guard_test.dart`, and a stale duplicate of the #121 comment in `tools/gate.sh` that recommended `|| true` was removed.
  **Why:** Both were false about this repository (the CLAUDE.md claims rule).
  **Issue:** #33, #34

## /n8-exec M1 (verification fix pass) -- 2026-09-24

- **Decision:** #38 (the GitHub-release attach step never ran) is carried, not fixed, in this pass.
  **Why:** Only a real GitHub release exercises it, and cutting one is `/n8-release`'s act, not a fix pass's. It is `sev:medium`, so it does not block M1's closure; it closes on the next release run that logs 'asset attached and its hash re-verified'.
  **Issue:** #38
- **Decision:** The secrets guard also forbids secrets in job- and workflow-level `env:`, not only in `run:` bodies and shell tracing.
  **Why:** release.yml's header promises step-level scoping; the guard makes that sentence executed rather than asserted (Rule 2).
  **Issue:** #35
- **Decision:** play-api-check's steps are tested by running their own `run:` bodies, extracted from the parsed workflow, under bash with gcloud/curl/keytool stubs.
  **Why:** A copy of the script in the test would drift from the workflow; running the workflow's text is what makes a regression in it visible.
  **Issue:** #41
- **Decision:** The certificate refusal is tested with a key generated in the test (keytool + jarsigner) and the committed certificate as the foreign one.
  **Why:** No real key material may be used; the release job's own certificate must be the one that fails to match.
  **Issue:** #37
- **Decision:** #39 and #40 share one commit: both change ci.yml's gate/mutations structure and are asserted in the same guard file.
  **Why:** Inseparable in those two files.
  **Issue:** #39, #40
