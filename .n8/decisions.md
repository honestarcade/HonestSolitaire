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

## /n8-verify M0,M1 (re-verification) -- 2026-09-24

- **Decision:** Guards defend against honest mistakes, not deliberate evasion (owner's choice, asked after ~20 nearby bypasses surfaced in one round). Plausible-accident findings were filed (#44–#49, #37 and #41 reopened); the deliberate shapes — a `/* */` or `if (false)` around the signing refusal, single-quoted or re-prefixed `tools:node`, the package id planted elsewhere in the manifest, a nested key borrowing a package's `# why:` — are recorded as not guarded by design in CLAUDE.md.
  **Why:** Filing every text-match bypass is the loop that took Honest Sudoku 18 rounds; code review and the ruleset own intent.
  **Issue:** #1, #2
- **Decision:** The owner's note that the launcher icon is the template's was logged against epic #7 (M5), not filed as an M0 failure.
  **Why:** No M0 criterion covers the icon; the design's icon is epic #7's acceptance criterion.
  **Issue:** #7

## /n8-exec M0 (second fix pass) -- 2026-09-24

- **Decision:** The identity guard reads package ids from the parsed workflows by key (`APP_PACKAGE_ID`, `packageName`, `PACKAGE`, and `play_promote.sh`'s argument) and requires each workflow to name at least one.
  **Why:** Matching by the studio prefix missed any other id. Requiring a value per file catches a workflow whose only package key is renamed; a file with several keys still passes if one is renamed (corrected 2026-09-24, #52).
  **Issue:** #44
- **Decision:** The `<uses-permission>` rule now covers every manifest except `src/debug` and `src/profile`; the `<permission*>` rule covers all.
  **Why:** Flutter's own dev-only INTERNET request lives in those two, which are never uploaded.
  **Issue:** #47
- **Decision:** Corrected comments name the command that computes a count instead of stating one.
  **Why:** CLAUDE.md's rule; the "7 failures" and "ONE test" sentences went stale exactly because they were counts.
  **Issue:** #48

## /n8-exec M1 (second fix pass) -- 2026-09-24

- **Decision:** Required jobs (gate, mutations, ship) and the safety steps (the gate and battery commands; the scan, certificate and Play steps) may carry no `if:` and no `continue-on-error`; steps that legitimately run conditionally (the PR-only artifact upload, the always-run summary and cleanup steps) are not in that set.
  **Why:** A skipped job satisfies a required check, so a skip is a pass; the conditional steps above report or clean up and gate nothing.
  **Issue:** #45
- **Decision:** Shell tracing is read from every `shell:` (step, job and workflow defaults) and from any `set` whose arguments carry an x flag or `-o xtrace`; `set +x` and `--long-options` are not tracing.
  **Why:** The debugging edits that plausibly leak a secret; the negative fixture pins the benign forms.
  **Issue:** #46
- **Decision:** The setup-script tests run on a PATH built from a dozen symlinked coreutils plus stubs, not `/usr/bin:/bin`.
  **Why:** GitHub's Ubuntu runners ship real `gh` and `gcloud` in /usr/bin; a test must not be able to reach them.
  **Issue:** #41

## /n8-plan M2 -- 2026-09-24

- **Decision:** M2 is twelve stories (#59–#70) under epic #3; the roadmap's single engine phase was re-sliced into the phases in the milestone description.
  **Why:** Vertical slices sized for one session each; the coverage check split Spider scoring out of the Spider rules story (#61 → #61 + #63) because one story owned more items than it had criteria.
  **Issue:** #3
- **Decision:** Owner answers, round one ("all recommended"): Spider scores 500 / −1 per move / +100 per run; Unlimited undo off = only the last move, never a draw/deal; undo never penalised; unlimited Klondike passes in every mode; foundation→tableau allowed (−15 standard); auto-finish triggers when every tableau card is face up and stock/waste are empty, FINISH as soon as every tableau card is face up; "No moves left" offers Undo and New deal; winnable deals Klondike only; the Settings toggle is the default and the New Klondike screen overrides per deal; winnable search shows progress, is cancellable, and after ~5 s offers keep searching or a random deal; the deal number is shown on the pause card.
  **Why:** Recorded on the stories that carry them, and on epic #5 for M4's screens; the replay-by-number feature was captured as #58.
  **Issue:** #59–#70, #5, #58
- **Decision:** Owner answers, round two: all recommended except time — "Time should have an impact on scoring. Faster solves, higher scores." The planner's rule, approved at the gate: −2 per 10 s in timed standard Klondike (floor 0), a 700,000 ÷ seconds (minimum 30 s) win bonus in timed games of both kinds, none in Vegas or untimed; the time penalty is tied to the clock so undo never refunds it; untimed games still count play time; restarting a won deal is allowed.
  **Why:** Classic Windows Klondike's time rules are the familiar reading of "faster solves, higher scores"; tying the penalty to the clock keeps undo from becoming a score exploit.
  **Issue:** #62, #63, #64
- **Decision:** Invariants 3 and 4 are annotated `guard: #70 (planned)`; the uniformity of a non-winnable shuffle is recorded as honor-system.
  **Why:** #70 is the guard story; measuring uniformity is not planned.
  **Issue:** #70

## /n8-plan M3 -- 2026-09-24

- **Decision:** M3 is ten stories (#72–#81) under epic #4, each blocked by the M2 engine stories it uses; the roadmap's single board phase was re-sliced.
  **Why:** The coverage check split the Klondike tap story (8 items, 6 criteria) into rendering (#74) and taps (#75) and made the Spider story's criteria one per item.
  **Issue:** #4
- **Decision:** Owner answers, round one ("all recommended"; long-press peek kept for both games after an explanation): illegal moves shake and clear; the clock starts at the first move and stops when paused, backgrounded or won; one-tap with no destination selects; hints are amber rings until the next action; "No moves left" is a non-covering banner with Undo and New deal; the win card's streak, See statistics and Main menu, and the pause card's Rules, Settings and Main menu, wait for M4 (DESCOPED in M3); auto-finish steps 60 ms apart until M5 animates; NEW deals the same options until M4's setup screens; a temporary pause-card switch reaches Spider until M4's menu; the board scales from the 390-point design.
  **Why:** M3 ships a playable board before the menus and settings exist; the temporary switch is removed by M4.
  **Issue:** #80, #81
- **Decision:** Owner answers, round two ("all good"): 23 behaviours covering clock resets and formats, tap semantics, drag highlights and peek bounds, pause-card and back behaviour, tool-row states, the banner's placement, large-card and left-handed layouts, the waste fan, edge-to-edge felt, the 480-point cap and ignoring system text size on the board. Gate defaults approved with "go": the cards always show full stats; a finished kept game deals fresh; a Spider stock tap within 300 ms of a deal is ignored; 48 dp minimum tap areas; the top bar does not mirror; the clock runs under the banner; wrong-suit foundation taps redirect; an empty stock with an empty waste shakes; a tap below a column acts on its top card.
  **Why:** Recorded on the stories that carry them.
  **Issue:** #72–#81

## /n8-plan M4 -- 2026-09-24

- **Decision:** M4 is twelve new stories (#83–#94) under epics #5 (screens) and #6 (persistence and statistics), plus #58 (replay by deal number) triaged into M4 and given its acceptance criteria; each is blocked by the M2/M3 issues it uses, and the menu (#94) lands last so its tests push the real screens.
  **Why:** The coverage check mapped 31 items from both epics, the design's non-board screens and M3's DESCOPED card buttons, all owned.
  **Issue:** #5, #6, #58
- **Decision:** Owner answers, round one ("all recommended"): a game counts once it has a move and abandoning it for a new deal of the same type is a loss that breaks the streak (closing the app is not); current streak only; best time from timed wins, fewest moves from any win, Vegas keeps lifetime dollars instead of a high score; breakdowns as designed; total play time counts every game; reset clears both games; one saved game per type, Continue resumes the last played; the splash lasts as long as loading (≥ 0.6 s); "New game" with nothing saved opens New Klondike; replay by number is a field on both setup screens, blank = random, and a chosen number can't be promised winnable.
  **Why:** Recorded on the stories that carry them.
  **Issue:** #83–#94, #58
- **Decision:** Owner answer, round two: Android's system backup stays allowed — "We will allow google cloud backup. That's a user decision, not ours. We don't send the data anywhere else, but if the user has a system-level feature turned on that does we won't stop it." The app sets no `android:allowBackup="false"`; #83 amends CLAUDE.md invariant 1 ("the app itself sends player data nowhere"), adds an `allowBackup` assertion to its platform-surface guard, and corrects `docs/privacy.md`; the Play data-safety answer must say the same (noted on epic #10, M7).
  **Why:** The invariant said "all player data stays on the device"; Android's own backup is the player's setting, not the app's transmission, and the app's copy must stay true under it.
  **Issue:** #83, #10
- **Decision:** Gate defaults approved with "go": Settings' "Stored on device only", About's No-accounts promise and the reset confirmation are reworded to stay true under backup ("Nothing was ever uploaded by this app, so it has no other copy."); Settings descriptions and About's statistics line are corrected to what was built; a stats reset records nothing for a game in progress (it counts in full when it ends); starting the other game type or going to the menu keeps the saved game; a deal from a setup screen opened in a game replaces that board, Keep playing returns to it unpaused; tabbed screens open on the caller's, current, last-played game, else Klondike; Spider gets a RECORDS card; the deal-number field drops non-digits and flags 0 or > 999999 live; several unreadable files give one combined banner until dismissed; Continue's Klondike meta shows draw and moves only; the splash holds READY then fades.
  **Why:** Product-facing guesses from the executor re-simulation, listed at the gate as "decided by the planner unless you say otherwise".
  **Issue:** #83–#94, #58

## /n8-plan M5 -- 2026-09-24

- **Decision:** M5 is fourteen stories (#96–#109) under epics #7 (brand, sound and haptics) and #8 (accessibility), each blocked by #94 and the M3/M4 issues it changes; the card backs stay delivered by M3's #72. The coverage check split the deal animation out of the card-motion story (#103 from #99) because that story owned six items with four criteria.
  **Why:** 30 items from both epics, the brand sheet and every "until M5" deferral in M3/M4, all owned by an acceptance criterion.
  **Issue:** #7, #8
- **Decision:** Owner answers, round one ("Recommendations are fine", with two notes): the sounds are generated now with ElevenLabs — "Generate one clip from prompt for now and put it into game. If I need to change any we'll do it during bug fixes." — not placeholders; the launcher icon is the dark tile ("Dark icon"), so epic #7's "dark and light variants" was amended with a comment. The rest as recommended: sounds on deal/flip/snap/chime with one sound per action by priority, music off by default and only on the board, media volume not the ringer, a sample snap when Sound effects is turned on; ticks on refusals, completed runs/foundations and the peek; ~180 ms slides, ~150 ms flips, a ~0.6 s tap-to-skip deal, a ~2 s waterfall win cascade; Card animations off leaves only quick fades and remove-animations makes everything instant; TalkBack plays by double-tap and per-card actions with spoken results; a dashed hint ring; failing dim colours adjusted just enough in the same hue; text scale honoured up to 1.3×.
  **Why:** Recorded on the stories that carry them. Epic #9's "final sound assets (owner-supplied)" is now met by #98's generated clips; M6 changes any the owner dislikes.
  **Issue:** #96–#109, #7, #9
- **Decision:** Owner answers, round two ("recommendations are fine. Elevenlabs plan is creator"): the icon uses Frog Across's exact corner geometry; the build run generates the five clips with the owner's key and records the Creator plan; music never interrupts another app's audio; the Haptics toggle gives a sample tick; the deal animates only for new deals and restarts; all 52 foundation cards cascade; TalkBack reads face-down cards per column, always selects on double-tap, and speaks hints; board cards are the one tap-target exception; the board's bars keep their height at large text.
  **Why:** Recorded on the stories that carry them.
  **Issue:** #97, #98, #101, #103, #104, #106–#109
- **Decision:** Gate defaults approved with "go": every in-app mark moves to Frog Across's corners; the start-screen-to-splash shift is accepted; the pause card rises like the win card; TalkBack skips the deal and the cascade; the phone's Touch feedback setting also silences ticks; the Haptics description names foundations and the peek; TalkBack announces selection; refused music retries on the next resume; quick fades remain with Card animations off; foundations show empty behind the win card. The red suit darkens from #C6483D to #C4453A to pass contrast under the owner's round-one contrast answer.
  **Why:** Product-facing guesses from the pass-2 re-simulation, listed at the gate.
  **Issue:** #97, #99, #102, #104, #105, #107, #108

## /n8-plan M6 -- 2026-09-25

- **Decision:** M6 is eight stories (#111–#118) under epic #9, all waiting on M5's last story (#109); the carried M1 bugs #56 and #57 moved into M6 to be fixed in #118, and #38 (the GitHub-release attach never ran) is closed by the first release candidate in #113.
  **Why:** 13 items from epic #9 and the carried bugs, all owned by an acceptance criterion; Honest Sudoku's M6 was planned but never executed, so its issue texts were the only model.
  **Issue:** #9, #38, #56, #57
- **Decision:** Owner answers, round one ("1) S26 Ultra / everything else good"): the reference device is a Samsung Galaxy S26 Ultra and there is no second device, so API 24 and the smallest screen are emulator runs, said plainly; release candidates are `v1.0.0-rc.N`; every option is exercised on the phone at least once (a sampling rule, not every combination); the owner runs the phone play-through and the accessibility sweep, the agent the emulators, timing and the end-to-end suite; 95 % of winnable searches must finish before the 5 s point on the phone, or the search is made faster (the point never moves); critical/high bugs must be fixed and medium/low may carry with the owner's OK; the end-to-end suite runs locally before each candidate, not in CI.
  **Why:** Recorded on the stories that carry them; epic #9's bug criterion was amended to match.
  **Issue:** #111–#118, #9
- **Decision:** Owner answers, round two ("recs fine except … If a clip is rejected, you will create me three versions to choose from. If those three are rejected the cycle will repeat three at a time (with feedback) until a suitable clip is found."): the severity rule (critical: crash, lost game or stats, unfinishable game; high: misleads or blocks play or visibly breaks the design on the S26; medium: noticeable but harmless; low: polish — the agent assigns, only the owner changes); rejected clips regenerated three versions per round with no cap; the TalkBack sweep is sighted, on short pre-found deals; test documents live in `qa/`, not the public `docs/` site. Epic #9's sound criterion was amended accordingly.
  **Why:** Recorded on the stories that carry them.
  **Issue:** #115, #116, #118, #9
- **Decision:** Gate defaults approved with "go": the end-to-end script never runs on the owner's phone unless asked (it uninstalls the app and its saves); the Spider TalkBack win is played by hand (auto-finish is Klondike-only); bugs no automated test can reach are fixed against a written manual check that failed first; emulator-only defects are high when content is unreadable or unreachable, otherwise medium or low; the owner adds their Google account to the internal testers list before rc.1; new sound options are heard as WAV files on the phone, not through an in-app build.
  **Why:** Product-facing guesses from the pass-2 re-simulation, listed at the gate.
  **Issue:** #112, #113, #114, #115, #116, #118
