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

## Ad-hoc -- 2026-09-23 — reconciled by /n8-replan 2026-09-29

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

## /n8-plan M7 -- 2026-09-26

- **Decision:** M7 is nine new stories (#120–#128) plus the existing #22 (extended with a production-refusal guard and relabelled comments) under epic #10, all waiting on M6's last story (#118); the coverage check split the declarations story in two (#121 privacy/ads/data safety, #122 rating/audience/countries). Epic #10's duplicated #22 criterion was removed.
  **Why:** 11 items from epic #10, all owned by an acceptance criterion; Honest Sudoku's planned M7 (#68–#75) was the model.
  **Issue:** #10, #22
- **Decision:** Owner answers, round one ("recs are good" with notes): the agent drafts the listing and the owner approves and uploads it (the CI account keeps release-only permissions); six script-made screenshots and a feature graphic, English only; contact email "Same as sudoku" (`support@honestarcade.app`); audience 13+; every country; testers are "a later step … I will line up testers for solitaire, sudoku, and frog across all at once"; production straight to 100 %; a fix during the hold ships as 1.0.N without restarting the clock; the README, a v1.0.0 GitHub release and the wiki record the launch.
  **Why:** Recorded on the stories that carry them.
  **Issue:** #120–#128
- **Decision:** Owner answers, round two ("all recs"): Vegas scoring is answered as not simulated gambling (no betting, no wager, no money), the resulting rating accepted; testers report problems to support@honestarcade.app; one tester note covers the three apps (Frog Across's paragraph left for the owner); only blocking bugs change the testers' build, the rest go to the backlog; the listing does not mention Android backup (it is in the data-safety answers and privacy policy); the owner approves the store images; the Statistics screenshot shows real numbers.
  **Why:** Recorded on the stories that carry them.
  **Issue:** #121–#126
- **Decision:** Gate defaults approved with "go": after launch testers are thanked and released and the closed track stays; the production release publishes on approval (managed publishing off); countries exclude only those Play says need a local licence or legal representative, each listed with Play's reason. M8's audit emphases are now final (every feature milestone is planned).
  **Why:** Product-facing guesses from the pass-2 re-simulation, listed at the gate.
  **Issue:** #122, #127, M8

## /n8-exec M2 -- 2026-09-26

- **Decision:** `lib/engine/game.dart` is one library with `klondike.dart`, `spider.dart`, `history.dart`, `serialization.dart` and `winnable_dealer.dart` as `part`s; `card.dart`, `rng.dart`, `deck.dart`, `deal_number.dart` and `scoring.dart` stay separate libraries.
  **Why:** The plan asks for sealed `Game` and `Move` supertypes (pass-2 notes on #60) and Dart allows a sealed type's subtypes only in the same library; the parts also share the library-private constructor that is the only way to mark a game `winnable` (#68's discretion).
  **Issue:** #60, #61
- **Decision:** `Flip` is a shared `Move`, not a `KlondikeMove` or `SpiderMove`, so `legalMoves()` returns `List<Move>` on both games.
  **Why:** Both games have the same flip rule and #64's limited-undo test treats them alike; two `Flip` classes would double every switch.
  **Issue:** #60, #61
- **Decision:** History is a chain (each game holds only its last `HistoryEntry`, whose `before` holds the one before), not a list stored on every snapshot; each entry also keeps the move's `Effects` so undo can animate the reversal.
  **Why:** O(1) per move and no list copying; the plan's "list of prior snapshots" was about behaviour, not storage.
  **Issue:** #64
- **Decision:** #60 and #61 share one commit (b8042fd).
  **Why:** Both write parts of `game.dart`, which does not compile with either part missing.
  **Issue:** #60, #61
- **Decision:** `Solved.moves` and `KlondikeGame.solution` are `List<Move>`, not `List<KlondikeMove>`.
  **Why:** `Flip` is a shared move, and a solution for a game with auto-flip off must carry its flips.
  **Issue:** #66
- **Decision:** The solver's transposition key sorts all seven columns, not only the empty ones; the default budget is 40,000 nodes (measured 2026-09-26 on the development Mac: 64 % draw 1, 47 % draw 3 over seeds 1–200, mean 226 / 303 ms per deal; at 60,000: 65 % / 48.5 %, 441 / 560 ms).
  **Why:** Klondike is symmetric under any column permutation, so the wider key loses no solution; the smaller budget keeps the floors with room under the 1 s mean on a slower CI runner.
  **Issue:** #66
- **Decision:** `solve` gained `allowFoundationToTableau` and the auto-finish fallback passes false.
  **Why:** Without it the fallback finished a board by pulling diamonds back off a foundation to re-align a draw-3 stock — legal, but FINISH must sweep up, never down, as the story's greedy description says.
  **Issue:** #67
- **Decision:** `canFinish` is memoised with an `Expando<bool>` in `finish.dart` rather than a field on `KlondikeGame`.
  **Why:** `finish.dart` is its own library and the game class needs no knowledge of the finish; the effect — one computation per immutable game object — is the same.
  **Issue:** #67
- **Decision:** The winnable worker sends its solution as move JSON and the main isolate re-deals and replays it before emitting `Found`; `Move.fromJson`, `KlondikeOptions.fromJson` and `SpiderOptions.fromJson` were written in #68 rather than #69 to carry that transport.
  **Why:** The plan's "second honesty check" needs a decoder before the serialization story lands; #69 reuses the same decoders.
  **Issue:** #68, #69
- **Decision:** Loading a saved game ticks the saved clock onto the fresh deal before replaying the history.
  **Why:** A won game's time bonus is computed by the winning `apply` from `elapsed`; replaying at zero would give a different bonus and fail the piles-follow-from-history check for every saved win. The clock stops at a win, so the saved elapsed is the winning one.
  **Issue:** #69
- **Decision:** The winnable guard starts its forty searches concurrently (one isolate each) instead of one after another.
  **Why:** Sequentially the guard would cost minutes on every slow mutation run; in parallel it finishes in seconds on a multi-core runner, with the same 60 s ceiling per search.
  **Issue:** #70
- **Decision:** The determinism guard's fresh-isolate check runs one `Isolate.run` per mode computing all 300 deals, not one per deal.
  **Why:** The plan's "fresh process state" is a fresh isolate; five spawns prove the same thing as fifteen hundred in a fraction of the time.
  **Issue:** #70

## /n8-exec M3 -- 2026-09-26

- **Decision:** The UI's pile type is `BoardPile` (`lib/ui/board/pile_ref.dart`), not `PileRef` as #73 names it.
  **Why:** The engine already exports `PileRef` for hints (#65); the controller converts at its boundary as #74's pass-2 note foresaw.
  **Issue:** #73, #74
- **Decision:** `GameController.move()` notifies its listeners itself; `displayGame` is a `GameNotifier` that notifies on every assignment.
  **Why:** A plain `ValueNotifier<Game>` stayed silent on clock ticks because game equality ignores `elapsed`, and widgets driven through `move()` in tests showed stale state.
  **Issue:** #75, #78
- **Decision:** UI tests host their controller in a `DisposingHost` widget (`test/ui/disposing_host.dart`) instead of a tear-down.
  **Why:** flutter_test checks for pending timers after unmounting the tree and before tear-downs run; a running clock must be disposed with the tree.
  **Issue:** #78
- **Decision:** The tool row draws the design's glyphs as text with Noto Symbols fallbacks and carries a build-time switch to Material icons (`useGlyphFallbackIcons`) rather than a runtime missing-glyph check.
  **Why:** Flutter reports no missing-glyph event at run time; the device check in #81's demo decides the switch, and M5 replaces the glyphs with the icon set anyway.
  **Issue:** #79
- **Decision:** `UiHint.move` takes an optional destination; a flip hint rings the face-down card alone.
  **Why:** #79's own discretion note; the engine's `Flip` has no destination pile.
  **Issue:** #79
- **Decision:** The pause card's Restart, New deal and Switch resume the game (unpause) as part of replacing it; `switchGame` keeps the other game on the controller (`keptGame`) and, when the kept game is won, deals a fresh one of its type.
  **Why:** #80's owner answers (round two and the gate defaults).
  **Issue:** #80
- **Decision:** The finish sweep commits `applyFinish` at once and shows per-step states through `shown`/`displayGame`; every input is blocked meanwhile; back, pause and backgrounding complete it instantly and show the win card.
  **Why:** #80's discretion: one undo step, the clock stops when the sweep starts so the time bonus uses that moment.
  **Issue:** #80
- **Decision:** The board's safe area is `MediaQuery.viewPadding` (the system bars), and both Android theme files inherit one `HonestDark` parent with a navy window background.
  **Why:** #81's discretion; one parent keeps light and dark mode identical, which the design is.
  **Issue:** #81

## Ad-hoc -- 2026-09-26 — reconciled by /n8-replan 2026-09-29

- **Change:** Invariant 1 now says the app itself sends player data nowhere, and that Android's own system backup, when the player has it on, may include the app's data in their Google account backup; the app does not set `android:allowBackup="false"`.
  **Why:** Owner, /n8-plan M4 round two (2026-09-24): "We will allow google cloud backup. That's a user decision, not ours. We don't send the data anywhere else, but if the user has a system-level feature turned on that does we won't stop it." Applied by #83 as planned; `docs/privacy.md` says the same.
  **Affects:** M7 (#121's Play data-safety answers must say the same); no other plan changes.

## /n8-exec M4 -- 2026-09-26


- **Decision:** Player data is written as versioned envelope documents (`{"format":1,"data":{...}}`) through one `AppStore` with atomic temp-file-and-rename writes, a per-document queue, and quarantine of an unreadable file to `.bad-<epochMillis>.json` (three kept) with a `corruptionNotices` list for the UI.
  **Why:** #83's discretion; a torn write must never lose the previous good file, and a corrupt one must be kept for the player to see rather than silently replaced.
  **Issue:** #83
- **Decision:** The files directory and URL opening go through the app's own method channel `honestsolitaire/platform` in `MainActivity.kt`; the guard `test/guards/platform_surface_test.dart` covers the channel's handled methods and `android:allowBackup` (mutations #83a–#83d).
  **Why:** Invariants 1 and 2 forbid a plugin for either; the owner's backup amendment (Ad-hoc above) is what the guard fixes in place.
  **Issue:** #83
- **Decision:** Saving is throttled to one write per 500 ms (leading and trailing) and flushed when the app pauses; `replaceGame` emits `Abandoned` only for a same-type game with a move, and the saved slot of the other type stays resumable.
  **Why:** #84's and #85's discretion notes; a rapid undo burst should not write every step, and a switch of game type is not a loss.
  **Issue:** #84, #85
- **Decision:** Statistics are pure functions over an immutable `StatsDocument`; a record arriving before the load completes is queued and applied once, and a won slot whose outcome was never recorded is reconciled at launch.
  **Why:** #85's discretion; the honest-count requirement (played once, won once) has to survive a crash between the win and the write.
  **Issue:** #85
- **Decision:** `GameScope` sits above the `Navigator` (MaterialApp `builder`) and carries the store, saves, stats, settings store, platform channel, winnable search and the navigation guard.
  **Why:** The Settings route pushed over the board could not see a scope placed at `home`; every M4 screen needs the same objects.
  **Issue:** #86, #87
- **Decision:** Settings descriptions are corrected to what the app does (unlimited undo off is "your last move, and never a draw"; winnable-only is Klondike only) and the version line reads `--dart-define` values with `dev` as the local fallback; `ci.yml` passes `HS_APP_BUILD=pr` and `tools/gate.sh` forwards it with the pubspec version.
  **Why:** #86's AC ask for honest copy; a version baked into source rots, so CI is the source (guard `release_version_test`, mutation #86).
  **Issue:** #86
- **Decision:** The splash and the search screen measure their minimum showing time with a `Future.delayed` started at init, not the wall clock; `DealerSearch` implements a `DealerHandle` interface so tests drive a fake stream.
  **Why:** flutter_test fakes timers but not `DateTime.now`, and the dealer's constructor is library-private.
  **Issue:** #87
- **Decision:** System back during the launch splash is left to the route beneath (the board today, the menu after #94); no observer intercepts it.
  **Why:** `WidgetsApp` handles `didPopRoute` before any observer registered after it, and both roots leave the app when nothing is in progress anyway.
  **Issue:** #87
- **Decision:** Until #94 puts the menu at the root, `openBoard` pushes the board above the launch board (`pushAndRemoveUntil(isFirst)`), so a found deal briefly stacks two boards.
  **Why:** The navigation stack's shape is #94's; building the menu early would fork it.
  **Issue:** #87
- **Decision:** The setup screens' Deal, Keep playing and reroll live in `lib/ui/navigation.dart` (`startNewGame`, `keepPlaying`, `keepPlayingTarget`, `freshDealNumber`) and both screens share `OptionPanel` / `ChoiceButton` / `DealButton` with a per-game `SetupAccent`; Spider's first-run defaults are the `firstRunSpider` constant #86 already put beside the settings store, not a new `SpiderOptions.firstRun`.
  **Why:** One home for the deal flow keeps #88 and #89 identical in behaviour; a second constant with the same value would be a fork.
  **Issue:** #88, #89
- **Decision:** `ScreenScaffold` bounds its pinned column with `IntrinsicHeight`, and card pairs in a scroll view (`Statistics`, the menu) sit in one too. *(Rule 1)*
  **Why:** A `Spacer` or a stretched `Row` inside an unbounded scroll view has no height to take; the first setup screen hit it.
  **Issue:** #88, #92, #94
- **Decision:** The deal-number `TextField` sits in a transparent `Material`; the About screens sit in a transparent `Scaffold`.
  **Why:** `TextField` and `SnackBar` need those ancestors and the plain `ScreenScaffold` has neither.
  **Issue:** #58, #91
- **Decision:** THE DEALS states the empty-column rule the engine plays (Strict: every column must hold a card before a deal; Relaxed lets you deal with one empty), not the pass-2 note's "a column can only take a run of one suit", which describes no rule the engine has.
  **Why:** The AC ask for the built rules; the guard holds only the numbers, so the wording is a judgement call, logged.
  **Issue:** #90
- **Decision:** `PauseCard` and `WinCard` read `GameScope.maybeOf`: with a scope, New deal opens the setup screen and the win card shows STREAK; without one (the board-only widget tests of #80) New deal deals directly and STREAK is absent. `ToolRow` takes an optional `onNew` the same way.
  **Why:** #80's tests pump `BoardView` alone with hand-built positions; rewriting them around the whole app would lose their precision for no behavioural gain.
  **Issue:** #93
- **Decision:** #93 and #94 share one commit.
  **Why:** Main menu on the cards pops to the first route, which only means the menu once #94 makes it the root; #93's tests cannot pass on the board-as-root stack.
  **Issue:** #93, #94
- **Decision:** The controller still starts with a random Klondike (never saved until it changes) rather than "no game"; the menu's Continue reuses it when it is the saved game and installs the slot otherwise. The corruption banner reads `AppStore.corruptionNotices` straight from the scope.
  **Why:** `GameController` requires a game and the board is only pushed with one; a nullable game would touch every board widget for a state that never shows.
  **Issue:** #94
- **Decision:** Screen tests settle route transitions with an explicit 900 ms pump (`settle(tester, transition: true)`) and `openScreen` tears the previous app down before pumping a new one.
  **Why:** This Flutter's Android page transition runs 800 ms, and `pumpAndSettle` never settles while the search screen's bar loops; a second `HonestSolitaireApp` in one test otherwise reuses the first `GameRoot` state and store.
  **Issue:** #87, #91

## /n8-exec M5 -- 2026-09-26

- **Decision:** The font files, hashes, sources and README table are Honest Sudoku's, copied byte for byte (not re-fetched); the README says whose dates they are.
  **Why:** #96's discretion; the pins are identical and `--check` proves the bytes here.
  **Issue:** #96
- **Decision:** One transparent `Material` sits above the Navigator in `GameRoot`, so every route inherits the theme's `DefaultTextStyle`. *(Rule 1)*
  **Why:** The M4 screens are plain `DecoratedBox` scaffolds; without a Material their text carried the framework's fallback style (yellow-underlined `monospace`), which the typography test exposed once real fonts were loaded.
  **Issue:** #96
- **Decision:** The template-placeholder guard skips `.ttf`, `.otf` and `.wav`. *(Rule 3)*
  **Why:** It reads every tracked file as UTF-8; the first bundled font made it throw. Binary assets carry no template text.
  **Issue:** #96
- **Decision:** Every mark in the app — card backs, splash, menu, About tile and the launcher icon — uses Honest Frog Across's corner geometry (`M 3 21 L 3 10 A 7 7 …`, stroke 6), taken from its `android-foreground-frog-mint.svg` on GitHub (sha256 `bad1e3e0…36a6`, read 2026-09-26), not the brand sheet's heavier `A 8.5` / stroke 7 drawing; the design's per-surface stroke scales (6, 7, 8) collapse to the one stroke.
  **Why:** Owner, /n8-plan M5 round two: "the icon uses Frog Across's exact corner geometry, stroke 6"; #97's AC5 extends it to every in-app mark, and one geometry is what `test/ui/mark_geometry_test.dart` can hold to `STUDIO-MARK.svg`.
  **Issue:** #97
- **Decision:** The template icon is recognised by length plus FNV-1a 64 of each density's bytes (recorded from android-studio-app-template 4f43e95), not SHA-256.
  **Why:** `package:crypto` is not a dependency (invariant 2) and the threat is the template surviving by accident, which a 64-bit fingerprint of a known file catches; a wrong but non-default image is outside the guard, as the story says.
  **Issue:** #97
- **Decision:** `tools/mutation_check.py` gains `deletes=` and `replaces_with=` as byte snapshots restored in the same `try/finally`; `tools/test_mutation_check.py` holds the round trip and runs under #98's unittest gate step (until then, by hand).
  **Why:** #97's discretion; a missing raster or the template icon back in place cannot be expressed as a text substitution.
  **Issue:** #97
- **Decision:** Epic #7's launcher-icon criterion stands as amended at planning ("Dark icon", 2026-09-24); the light tile is not shipped and nothing is added to the epic.
  **Why:** #97's AC6; the amendment is quoted in the epic's comment and delivered here.
  **Issue:** #97
- **Decision:** The five clips were generated once each on 2026-09-27 from the prompts in `assets/audio/PROMPTS.md` (ElevenLabs `eleven_text_to_sound_v2`, Creator plan, the owner's key from `~/HonestArcadeApps/secrets/elevenlabs.env`), with no auditioning; the loop is mono at −15 dBFS peak, untrimmed.
  **Why:** Owner, /n8-plan M5 round one ("Generate one clip from prompt for now…"); the exec session runs the generation (round two). The WAVs are the artifacts of record; the script cannot reproduce them.
  **Issue:** #98
- **Decision:** `tools/gate.sh` runs the tools' Python unit tests as step 2 through a shell function (`run_python_tests`, discovery finding nothing is not a failure) and finds the build step by its label; the six-step wording in CLAUDE.md and the README becomes seven.
  **Why:** #98's discretion; `run_step` executes an array of words, and a function name is one.
  **Issue:** #98
- **Decision:** `Card.id` is presentation identity only — the unshuffled deck index, carried through shuffles and flips, outside `==`/`hashCode`, never saved; both `fromPiles` assign it by rank and suit through `identifyPiles` (Spider duplicates by occurrence order); the board falls back to a rank/suit/occurrence id when a card has none.
  **Why:** #99's pass-2 discretion; a restored game is re-dealt and replayed (#69), so its cards get ids from `deal` and the save format is untouched.
  **Issue:** #99
- **Decision:** Every test runs with `MediaQuery.disableAnimations` on (`test/flutter_test_config.dart`); the motion tests opt back in.
  **Why:** The M3/M4 suites read a card's rect right after a move and tap it, which is only true when the board snaps; the setting is the phone's own switch, so the suites exercise the reduced-motion path the story requires.
  **Issue:** #99
- **Decision:** A card that only flips (the one a move uncovered) starts its flip when the slides land; a card that slides and flips (a stock draw) flips as it lands; a released drag settles from its last drawn rect; a running spring-back is finished by the next drag rather than blocking it; under `AppMotion.none` the controller skips the spring-back and completes the finish sweep at once.
  **Why:** #99's discretion, made concrete where the story left the order to the implementation.
  **Issue:** #99
- **Decision:** Inline glyphs (↗ in a link, → in the support panel) sit on the line's middle (`PlaceholderAlignment.middle`), not on the baseline through a `Baseline` wrapper as the pass-2 note asked.
  **Why:** A baseline placeholder asks the painted box for a dry baseline, which `RenderCustomPaint` does not provide, and the screen scaffold's pinned layout runs under `IntrinsicHeight`; the About screens threw during layout.
  **Issue:** #100
- **Decision:** The engine's and the hint's `toString` debug strings write `->` instead of `→`.
  **Why:** They are string literals under `lib/`, so the glyph scan reads them; ASCII loses nothing in a debug string, and an exemption for them would be a second prose list to keep.
  **Issue:** #100
- **Decision:** The controller publishes one `FeedbackStep` per action, derived from the committed states (flips by card id in the tableau, runs and foundations completed, wins, a Spider row dealt) and stated explicitly for undo, restart, new deal, refusal and peek; `clipFor` reduces it to one clip (chime > deal > flip > snap; Kings inside the sweep do not chime, the win does). The music gate serialises its bridge calls and keeps one start in flight.
  **Why:** #101's discretion; deriving from states needs no move type and covers taps, drops, hints and undos alike. A settings change notifies the controller too, which queued a second `musicStart` until the in-flight flag.
  **Issue:** #101
- **Decision:** The platform-surface guard's `when`-block parser is brace-balanced (it used to stop at the first 16-space `}`, which the sound bridge's nested `if` has) and now also holds the sound channel's six methods, both channel names, the two registrations, and the bridge's and activity's audio facts.
  **Why:** #101's AC; the old parser was written against MainActivity's indentation and read one method from SoundBridge.kt.
  **Issue:** #101
- **Decision:** Every dim text token is nudged against one shared surface set — the felt's three stops, the two panel fills over navy and the card navy — so one value passes everywhere the token sits; that lifts more tokens than the planner measured on plain navy alone (`textBody`, `mist`, `textViolet` fail only on the felt's brightest stop #0A3A80), and the nudged shades are the guard's own output: `textMuted` #93AACB, `textFaint` #90AAC8, `textKicker` #8FABD1, `textBody` #8BACD1, `mist` #87ABDA, `textViolet` #BB96FF, `textAccentSoft` #06BDB3 (teal at 70 % made opaque), `textHint` #98A9C3 (pale text at 50 % made opaque), `textOnTealSoft` #03535D (ink at 70 % on teal). `readout`, `textSoft`, `textBright`, `textBlue`, `amber` and `errorText` already pass and stay the design's.
  **Why:** #102's pass-2 discretion ("one nudge that passes every surface they sit on"); the loading label and the splash sit on the gradient's top stop.
  **Issue:** #102
- **Decision:** The card rings are a `RingPainter` (a solid 2 px teal stroke, a dashed 6/4 amber stroke) over the card rather than spread shadows; hinted empty slots and Spider's hinted stock (one ring around the sliver group) use the same dash from `dashPath` in `slot_painter.dart`.
  **Why:** #102's AC1 and discretion; a spread shadow cannot be dashed.
  **Issue:** #102
- **Decision:** The deal is a #99 motion plan (`planDeal`) held at 0 until the board route's transition completes, consumed from a one-shot `pendingDeal` token the board compares with the value it saw when it was created; `replaceGame(…, dealAnimation: true)` (setup Deal, `Found`, random-instead, NEW/New deal) and `restart()` raise it, resumes never. A pointer-down during the deal lands it — consumed on the board, passed through on the bars — and pause, a layout change or another install land it too. Under reduced motion or `accessibleNavigation` there is no deal.
  **Why:** #103's discretion; reusing the motion layer keeps one ticker and one snap rule; #105's cross-fade will be the transition the deal waits for.
  **Issue:** #103
- **Decision:** The cascade is an overlay of positioned `PlayingCard`s driven by one `AnimationController` (`planCascade` in `lib/ui/board/win_cascade.dart`), not cards rasterised to images under one `CustomPainter`; the controller's win-card timer hands over to a `beforeWinCard` hook the board installs (record wait ≤ 2 s → last slide lands → cascade → card), and `onSkipWin` ends it (a pointer-down on the board, system back, a background, a new install, an undo, a resize). Foundations draw empty while the cascade owns their cards and once the win card is up, cascade or not.
  **Why:** #104's discretion; the same widget the board paints keeps the cards pixel-identical with no raster pass, and the board already has the moving-layer pattern from #99.
  **Issue:** #104
- **Decision:** During the cascade the tool row keeps RESTART and NEW enabled (they act and end the sequence, as the story asks); UNDO stays disabled because the engine refuses an undo past a win (`_canUndo` in `lib/engine/history.dart`), so the story's "UNDO acts" cannot hold without an engine change (Rule 4 territory) — HINT and FINISH stay disabled on a won board as in #79. The #79 and #80 tests were updated in place: with animations on, the sweep's win card now follows the cascade; system back mid-sweep completes the sweep and shows the card at once.
  **Why:** The test plan named UNDO; the engine rule predates it and is the safer behaviour (a recorded win is not undone).
  **Issue:** #104
- **Decision:** `AppMotion` (`lib/ui/motion.dart`) gains `reduced`; every card-motion check that read `== none` now reads `!cards`, so Card animations off keeps the finish sweep completing at once and the spring-back instant (as #99 shipped it) while UI fades run 100 ms. The menu is a `FadePageRoute` through `onGenerateRoute` rather than `home`: a `MaterialPageRoute` below refuses its secondary animation for a route of another kind, so the menu never faded beneath a pushed screen; the `PageTransitionsTheme` backstop stays for anything the framework makes. `NavigationGuard` skips the lock when the route's transition (or reverse) duration is zero, since a push's proxy animation reads `completed` before its controller attaches.
  **Why:** #105's discretion, made concrete where the story left the mechanism open; the proxy-status detail is what a status check alone would have got wrong.
  **Issue:** #105
- **Decision:** The pause and win cards rise through `Appear`/`Risen` (`lib/ui/widgets/appear.dart`): the whole overlay fades, only the card translates; the same `Appear` (fade only) fronts the corruption and no-moves banners. The switch is an `AnimatedContainer` keyed `switch` with the knob keyed `switch-knob` (the old `switch-on`/`switch-off` keys had to go: a key that changes with the value recreates the widget and kills the slide). The indeterminate search bar under `none` stops at rest as a static segment; Rules/Stats scroll-to-top animates 150 ms under full. The M3/M4 tests that counted tickers or asserted the splash timings were updated in place and now opt into animations where they assert design timings.
  **Why:** #105's discretion and the story's "update that story's tests in place" convention.
  **Issue:** #105
- **Decision:** The text-size clamp (1.0–1.3×) wraps `GameRoot` in `MaterialApp.builder`; `ScreenScaffold`, `BoardScreen`, `TopBar`, `ToolRow` and `GameOverlays` lost their `withNoTextScaling`; the fixed drawings that opt out are `PlayingCard`, the empty-slot label, the menu and splash wordmarks, the About tile and the Settings swatch captions. The top bar's readouts and the tool-row labels sit in `FittedBox(scaleDown)` with the bars' heights unchanged (the tool button has room under its icon; the pill has room within its 44 px); the no-moves banner's message is fitted the same way. The large-text guard (`test/guards/large_text_test.dart`, every `AppRoute` × the board's states × Large cards × Left-handed at 320×568, bundled fonts) found no other screen overflowing or clipping at 1.3×, so the planner's fallback changes (minimum-height text boxes, wrapping setup labels and stat rows, two-line headers) were not made: each would have been a change with no failing case behind it.
  **Why:** #106's AC and discretion; the guard is the evidence that the M4 layouts already grow with their text.
  **Issue:** #106
- **Decision:** `BoardScreen` stays in `lib/ui/app.dart` (the planner's `board_screen.dart` never existed); the board mutation wraps the `board` local there. The guard's "1.3× or fitted" check reads the keyed `board-title` paragraph.
  **Why:** implementation-detail staleness, adjusted inline.
  **Issue:** #106
- **Decision:** Ticks fan out from `GameFeedback` (`tickFor`: `refused`, `runCompleted`, `foundationCompleted`, `peek`, one per step) through `HapticsPort.tick()`; the controller's own `_haptic()` and the peek's `selectionClick` are gone, every refusal publishes `refused` (a refused move or deal through the shake, a refusal with nothing to shake directly), and a peek publishes only when it can peek. `GameFeedback` takes the port as an optional fourth argument so the M5 sound tests stand. The haptics scan reads string literals as well as code (`stripDartComments` keeps them), so the channel's method name cannot be invoked by hand either.
  **Why:** #107's discretion; the setting is checked in exactly one place.
  **Issue:** #107
- **Decision:** TalkBack's board is a semantics layer in `board_view.dart` (`_semanticsLayer`) built from `board_semantics.dart`'s pure functions: one node per pile, per visible face-up card (keyed by `Card.id`) and per column's face-down cards, at the layout's rects; the painted cards and slots are `ExcludeSemantics`. Columns with face-up cards have no extra "Column N" pile node — the top card is the place target and the face-down node places on the column too; the planner's separate pile node would have doubled every column in traversal. Announcements come from the controller's `spoken` step (`describeStep`/`describeRefusal`/`describeHint` in the controller's own `_apply`, `move`, `hint`, `undo`, `restart`, `replaceGame`, `_startSweep`) through `BoardAnnouncements` and one `Announcer` (`lib/ui/a11y/announcer.dart`), which speaks only under `accessibleNavigation`; the five M4 announce sites moved onto it, including the ones that used to speak regardless. The bars keep their own nodes through `Semantics(explicitChildNodes: true)` around each, ordered before and after the board's nodes with `OrdinalSortKey`s.
  **Why:** #108's discretion; a plain `Semantics(sortKey:)` around a bar merges the bar into one node, which the control-label test caught.
  **Issue:** #108
- **Decision:** `alwaysSelect` on the controller (set by the board from `accessibleNavigation`) makes every tap select with One-tap on; custom actions apply through `applyMove`, the tap-move path with the source as the shake target. Selection announcements ("… selected", "Selection cleared") are made only when the tap said nothing else. Draw announces the new waste top in lower case ("Drew nine of diamonds") like the other card names inside a sentence.
  **Why:** #108's discretion; the planner's product guess on selection wording, kept.
  **Issue:** #108
- **Decision:** The guideline guard (`test/guards/accessibility_guidelines_test.dart`) runs the framework's tap-target rule through `RecordingTapTargetGuideline` (`test/helpers/a11y.dart`, the framework's private traversal re-implemented so tagged nodes are skipped and every flagged node recorded) and its text-contrast rule through `ReadableTextContrastGuideline`, which skips nodes under 16 logical px tall and text fields: the framework samples the screen at logical resolution and takes the most frequent light colour, so a 9 px letter-spaced kicker, a 1.9 px "·" or a field with one glyph reports a blended colour whatever its real one (measured 1.01–2.73:1 on tokens #102 holds at 4.5:1 by computation). That is a per-node contrast exception the planner said not to make; the alternative was a guideline that can never pass on this design's small caps, and #102's computed guard is the proof for exactly those tokens.
  **Why:** #109's AC needs `textContrastGuideline` green and true; the sampler's limit is the framework's, not the palette's.
  **Issue:** #109
- **Decision:** Defects the guidelines found, fixed here (Rule 2): 22 controls whose `Semantics(excludeSemantics: true)` dropped the inner `GestureDetector`'s tap action (TalkBack could name them but not activate them) now set `onTap` on the Semantics too; the pause pill's and the no-moves banner's buttons have 48 dp hit boxes with their drawings unchanged (the bar's positioned rect grows to 48 dp, the row aligns to its top and centres each child on the drawn band); the game tabs grow from 40 to 48 dp; the deal-number field fills a 50 dp box (48 inside its border) and the clear and dismiss buttons are 48 dp; empty tableau columns' nodes are widened to 48 dp like #73's top-row hit rects; the foundation's card node uses the widened rect; the scrim under the pause and win cards is no longer a semantic tap; the About screens' "·" separators are excluded from semantics; `mist` is nudged to #96B6DF (#102's mechanism, with the About tile's panel over the felt's brightest stop, #164486, added to its surfaces after the guideline measured 4.48:1); the Statistics reset confirm uses `Palette.red` (white on the design's #E05A4E measured 3.66:1).
  **Why:** each is a guideline failure on a real screen state; the planner asked for real defects to be fixed in this story.
  **Issue:** #109
- **Decision:** Spider's completed-runs node is read-only, so it is listed among the exempt kinds as not tappable (the guideline never measures it) and the guard asserts it is never flagged; the splash case is held on SHUFFLING by a launch step that never completes rather than a store whose first read hangs (the store has no such seam; the splash is the same widget either way).
  **Why:** the AC lists the completed slots and the splash; both are covered by their actual mechanism.
  **Issue:** #109
- **Decision:** The guideline guard checks contrast by computation, not by the framework's `textContrastGuideline`: `CheckedTextGuideline` (`test/helpers/a11y.dart`) requires every text colour drawn on a screen to be a `Palette.textPairs` foreground, which `test/guards/contrast_test.dart` proves at its ratio on every surface it sits on. The sampled guideline renders at logical resolution and takes the most frequent light colour, and the same tokens that passed on the Mac measured 4.36–4.46:1 on the Linux runner (PR #134, run 36302842503, 2026-09-27): a gate check cannot depend on the rasteriser. The one text it found outside the proven set, the empty stock's "EMPTY" at 30 % white, now uses `Palette.placeholderSuit`, the alpha #102 proves for placeholders on the felt.
  **Why:** #109's AC names `textContrastGuideline`; a check that flips between machines is not a proof, and #102's arithmetic is.
  **Issue:** #109
- **Decision (Rule 3):** `ci.yml`'s mutations job timeout rises from 30 to 60 minutes: PR #134's battery (63 entries, three of them `slow`) was cancelled at entry 54 by the 30-minute default with every entry caught so far (run 36303295153, 2026-09-27); the workflow's own comment named this failure in advance.
  **Why:** a cancelled check is not a red one, and the battery is the guards' own gate; splitting it across jobs is a later choice if it keeps growing.
  **Issue:** #109 (the M5 PR)

## /n8-exec M5 (fix pass) -- 2026-09-27

- **Decision:** Fixed the four bugs `/n8-verify` filed against M5 (#144-#147), all test-coverage gaps rather than behavioral defects. #144: added the deal's untested Card-animations-off complement, a TalkBack-skip test, and tool-row/system-back-mid-deal tests to `test/ui/deal_animation_test.dart`; renamed the existing mislabeled "reduced motion" test to name what it actually exercises (remove-animations). #145: broadened `large_text_test.dart`'s "card faces never scale" check into a "fixed drawings never scale" check covering all 6 categories the AC names, selecting each by a structural ancestor key one level above its `noScaling`/`withNoTextScaling` line (so deleting that line still leaves the paragraph selected, showing up as a size mismatch instead of silently vanishing from the set) rather than by the scaler property itself, which would have the same blind spot the bug reported. Four widgets (`_Wordmark`, `_Title`, the About tile's `Panel`) needed a `key`/`super.key` added since none existed; added mutation `#106c` and manually confirmed (throwaway edit, reverted) that stripping the Settings swatch's wrapping the same way also turns the new assertion red. #146/#147: added the missing flip-specific and TalkBack-specific complement tests to `card_motion_test.dart`/`win_cascade_test.dart`; both rely on already-tested shared gates, so no new guard/mutation was added for either, consistent with #99's existing story not having one.
  **Why:** all four were "a missing complement is confirmed" findings from `/n8-verify`'s own rule; #144 and #145 were sev:high and blocked M5's closure.
  **Issue:** #144, #145, #146, #147

## Ad-hoc (carried-bugs fix pass) -- 2026-09-27 — reconciled by /n8-replan 2026-09-29

- **Decision:** #77's plan called for a separate `drag_layer.dart` file for `_dragLayer`/`_dragTargets`; that was never done, and unlike #73's analogous rename it was never logged. Kept inline in `board_view.dart` rather than extracted now — both are private methods on `BoardViewState` that read the same layout/controller state every other build-time method there does, with no caller outside this class; splitting them into their own file today would be a file-organization change with no behavior or test benefit, not a fix. Documenting the decision here is the fix `/n8-verify` asked for.
  **Why:** #139 flagged the missing log entry, not a functional defect; CLAUDE.md's own guidance is against introducing an abstraction (a new file/module boundary) beyond what a change requires.
  **Issue:** #139

## Ad-hoc -- 2026-09-27 — reconciled by /n8-replan 2026-09-29

- **Decision:** The first release after M0-M5 is `v0.2.0`, not `v1.0.0-rc.1` as the M7 plan's round-one answer named release candidates. The owner: this build hasn't been through their own testing or a bug-fixing pass yet, and `rc` is reserved for the point M7 actually opens testing to outside testers. `v0.2.0` reflects the real capability jump (infrastructure-only to a fully playable app) without claiming release-candidate readiness.
  **Why:** owner's explicit correction during `/n8-release`, overriding the M7 planning note recorded 2026-09-26.
  **Issue:** M7 planning may assume rc versioning starts earlier than M6 (testing and bug fixing) completes -- worth an `/n8-replan M7` pass if the rc-numbering scheme needs adjusting once M6 is scoped.

## /n8-release v0.2.0 -- 2026-09-27

- **Decision:** Released `v0.2.0` at commit `7de2f3c3fb95ce21ca04ae70960bf6026fd5fbf0`, covering M0-M5 (infrastructure, CI, the solitaire engine, board and play, screens/persistence/statistics, brand/sound/accessibility). Created the GitHub Release before the tag (release.yml never creates it itself), which let run 36340218909's asset-attach step take its real path for the first time and close #38. Uploaded to Google Play's internal testing track by the same run.
  **Why:** every milestone in scope was verified-closed with zero open confirmed bugs anywhere (the nine carried from `/n8-verify` were fixed first, see the `/n8-exec` fix-pass entries above), CI was green at the tip, and the owner named `v0.2.0` over the plan's `v1.0.0-rc.1` for this point in the process.
  **Issue:** none directly; closes #38.

## /n8-replan M6 -- 2026-09-29

- **Decision:** Replanned M6 around the owner's versioning decision (Ad-hoc 2026-09-27): release candidates start in M7, so M6 ends with an internal build (`v0.2.N`), not `v1.0.0-rc.1`. Changed: epic #9's goal and first criterion (owner-approved epic change), the milestone's goal, outcome 1, coverage items 1 and 10, phases and a "Replanned" note; every story's shared context; #113 retitled "Harden the release pipeline and put the internal build on the owner's phone" (rc cut, `1.0.0+1` bump, #38 closing and e2e-before-tagging removed — #38 was closed by v0.2.0's run 36340218909, and the owner installed v0.2.0 from the internal test link); #118 retitled "…re-check the final internal build" (e2e-before-tagging moved here); #112 now requires the Klondike win through FINISH and no Continue afterwards (after #152); #114/#115 run on the current internal build, #115 transcribes the owner's 2026-09-29 play-through. #114–#117 no longer wait on #113, #113 no longer waits on #112, #118 now waits on #112 and #113. #152 relabelled `sev:critical` under the owner's M6 severity rule ("loses a game or statistics").
  **Why:** executing M6 as planned would have tagged `v1.0.0-rc.1`, which the owner rejected; `/n8-exec M6` stopped on that drift.
  **Issue:** #9, #111–#118, #152. The 2026-09-27 Ad-hoc entry stays unreconciled until M7 is replanned (#124 cuts `1.0.0` straight to closed testing, and every M7 story's context names rc).

## /n8-replan M7 -- 2026-09-29

- **Decision:** The closed test runs release candidates `v1.0.0-rc.N`, and production gets `v1.0.0` rebuilt at the last rc's commit with only the version line changed. The owner chose the rebuild over promoting the rc binary itself, so the store shows 1.0.0 while testers and the public run the same app code (`tools/app_diff.sh` proves it). Changed: every M7 story's shared context; #124 retitled "Cut the first release candidate and put it on the closed-testing track" (tags `v1.0.0-rc.1` as a prerelease; retries are `rc.N`; the pubspec version bump moves here from #113); #127 gains the `v1.0.0` cut and its promotion to closed before the owner's production click; #126's hold fixes ship as rc builds; #123 gains rc release notes; #22's first dispatch promotes `1.0.0-rc.1`; the milestone's outcome 6, phases 3 and 6, and a "Replanned" note. Epic #10 unchanged; no closures, no new stories, no dependency changes.
  **Why:** the owner's 2026-09-27 versioning decision ("rc will be when it goes to testing with other testers") put the rc at exactly the point M7's closed test begins; #124 as planned tagged plain `1.0.0` there.
  **Issue:** #22, #120–#128. Reconciled Ad-hoc entries: 2026-09-23 (first promotion moved to M7 — already carried by #22 and #124), 2026-09-26 (backup wording — already carried by #121), 2026-09-27 (versioning — M6 on 2026-09-29, M7 here), 2026-09-27 carried-bugs (#139's `drag_layer` log — affects no plan).

## /n8-exec M6 -- 2026-09-29

- **Decision:** The owner's three play-through bugs (#152 sev:critical, #153, #154) were fixed first on the milestone branch, each with its failing-first test, before any story work: #118 (the final internal build) waits on them and #112's suite asserts #152's route on a device.
  **Why:** M6's shared context: every finding is filed and fixed in M6; a critical bug in the win bookkeeping would have made every later device run record a wrong statistic.
  **Issue:** #152, #153, #154
- **Decision:** #154 departs from the design's grey "Keep playing" button: it now wears the setup screen's accent (fill, 1.5 px border, 14/w600 text), with amendment comments on #88, #89 and #91.
  **Why:** the owner's words on 2026-09-29: "Make it a more pop 'color'".
  **Issue:** #154
- **Decision (Rule 3):** `tools/gate.sh` and `release.yml` build the release bundle without `--no-pub`. After a plain `pub get` the generated plugin registrant names `integration_test`, and a `--no-pub` release build then fails to compile; the build's own `pub get` regenerates the registrant without dev plugins.
  **Why:** adding the dev-only SDK package (#112) broke the release build otherwise; `tools/check_aab.sh` now refuses a bundle that carries `IntegrationTestPlugin` (exit 5), so nothing can ship through this change.
  **Issue:** #112
- **Decision:** #112's Spider deal comes from a test-only beam search (`integration_test/support/spider_search.dart`, width 150, deals from 1000), not the planned hint-following playout.
  **Why:** a hint-following playout won 0 of 500 deals on the host (it loops); a depth-first search found lines of 574–3498 moves. The beam wins deal 1000 in 113 moves, and its line meets a strict-deal refusal (an empty column with rows left) at move index 21, which the test asserts on the board and on disk.
  **Issue:** #112
- **Decision:** #112's phases hand the elapsed time over through `--dart-define=E2E_ELAPSED_MS` set by `tools/e2e.sh`, not the planned `e2e_handoff.json`; phase 2 recomputes the deal and its line from the same deterministic search. The app stays installed between phases through `flutter test --no-uninstall`.
  **Why:** a handoff file inside the app's data would sit next to the saves the test is checking; everything else in it is deterministic (invariant 3) and needs no handoff.
  **Issue:** #112
- **Decision:** #112 runs debug builds (`flutter test` on a device builds nothing else), not the planned `--profile`; the planned exit 3 for a rejected profile is replaced by exit 3 for a missing or unauthorised device.
  **Why:** `--profile` would need `flutter drive` with a driver file for a suite that checks behaviour, not timing; timing on a profile build stays #117's job.
  **Issue:** #112, #117
- **Decision:** #112's dead-end deal is found by following hints from deal 1000 until `hint()` says no move is left (host: deal 1001 after 78 moves), and empty columns are tapped at their slot's centre rather than through semantics actions.
  **Why:** no Klondike deal from 1000 is dead at deal time; the slot's own hit area is the path a player's finger takes.
  **Issue:** #112
- **Decision:** The end-to-end comparison ignores `elapsedMs` (checked separately within +1 s) and `lastUndone`, which a replay of the same moves never sets.
  **Why:** undo followed by the same move is the state the test compares against a straight replay.
  **Issue:** #112
- **Decision:** Filed #159 (sev:high, confirmed) from #112's first phase-2 run and fixed it in M6: a kill after backgrounding lost the play time since the last written move (restored 3744 ms, 6995 ms at backgrounding).
  **Why:** owner's M6 severity rule: a wrong statistic (best time) and time bonus misleads.
  **Issue:** #159, #112
- **Decision:** `.claude/` is excluded in `.git/info/exclude` on this machine (agent worktrees), not in `.gitignore`.
  **Why:** it is local tooling state, not something the repository should know about.
  **Issue:** none
- **Decision:** #117's golden gains deal numbers 1000, 31337, 500000 and 999998 in every mode (35 records); the 15 existing pins are byte-identical after regeneration. `integration_test/golden_deals.g.dart` is a const map, and #70's guard imports it and compares entry by entry with the JSON rather than comparing file text.
  **Why:** a semantic comparison cannot go red over formatting, and the device test imports the same map without file access; mutation `#117a` changes one piles string in the `.g.dart`.
  **Issue:** #117, #70
- **Decision:** #117's deals tried is computed as found − base + 1 (wrapping), not taken from the last Progress event; timing starts before `WinnableDealer.search()`, so isolate spawn is included. The 95 % statistics live in `tools/perf_report.py` (unit-tested), not in the device test.
  **Why:** the found number is exact; Progress is throttled to ten a second and can lag. Python keeps the arithmetic testable in the gate's tools step.
  **Issue:** #117
- **Decision:** #114's layout checks run as an integration test on the device (`integration_test/layout_sweep_test.dart` via `tools/layout.sh`): every route with Large cards off and on, at font 1.0 and the device's largest, failing on overflow or ellipsis outside #106's allowlist, with screenshots judged by the agent. Not adb taps screen by screen, as the plan described.
  **Why:** the framework's own overflow report and the paragraph's `didExceedMaxLines` are exact where a screenshot is a judgement; the screenshots remain for what only eyes can judge (bars, overlap, reachability).
  **Issue:** #114
- **Decision (Rule 1):** `tools/avd.sh` no longer pipes `yes` into sdkmanager: under `pipefail` the pipeline reported yes's SIGPIPE as a failed install after the API 24 image had installed. It now checks that the image's `system.img` exists.
  **Why:** found booting `solitaire-api24` for the first time.
  **Issue:** #114, #112
- **Decision:** `tools/e2e.sh` runs `integration_test/*_game_test.dart`, not "every `*_test.dart` except `perf_test.dart`" as #112's AC words it.
  **Why:** #114's layout sweep is also an integration test, and it is a single-phase run with its own script; the game files are the two-phase suite.
  **Issue:** #112, #114
- **Decision:** PR #157 (#113's pipeline half) and PR #158 (#56, #57) were built by background agents on branches off `main` and merged to `main` directly after their CI went green, each reviewed first; #113 stays open for its owner step.
  **Why:** they touch CI and guards only, and landing them on `main` early let every later branch build on them.
  **Issue:** #113, #56, #57
- **Decision:** `release.yml` now creates the GitHub release for a pushed tag when none exists, in a step (`id: release`) after the bundle scan and certificate check and before the attach: title "Honest Solitaire <version name>", notes generated from the previous tag (the previous final tag for a final release), and a prerelease not marked Latest for a tag with a `-` suffix such as `v1.0.0-rc.N`. An existing release -- as `/n8-release` creates one with the tag -- is reused untouched. The attach step's not-found branch is now a failure, the `no-release-note` summary note is gone (the summary shows the release URL and prerelease flag, `n/a` if the release step never ran), and a failure after the release step prepends "did not reach Play" to the release notes. `tools/check_aab.sh` also refuses any `debuggable` string in the bundle manifest (exit 6, `DEBUGGABLE:`).
  **Why:** a tag pushed without `/n8-release` used to go green with the bundle attached nowhere and its hash never re-checked; #113 makes that impossible rather than relying on the release being made first. `/n8-release` does not need to change: it may keep creating the release, and the workflow leaves it alone.
  **Issue:** #113 (mutations `#38`, `#113` in `tools/mutation_check.py`)
## #116 accessibility sweep -- 2026-09-30

- **Decision:** The Spider scan in `tools/find_a11y_deals.dart` was run over deals 1–1000, not 1–5000; it chose deal 924 (88 moves). The Klondike scan covered 1–5000 and chose deal 2982 (35 moves before FINISH).
  **Why:** the #112 beam search took 14–30 s a deal and the 1–1000 run took 1965 s with 10 workers on the development machine (agent, 2026-09-30, `/usr/bin/time` over the tool); 1–5000 would have taken hours. The tool still defaults to 5000 for anyone with the time.
  **Issue:** #116
- **Decision:** The Klondike TalkBack win ends with the owner double-tapping FINISH, not with Auto-finish starting by itself.
  **Why:** the fewest-moves-before-`canFinish` deal leaves cards in the stock, and Auto-finish starts itself only on an empty stock and waste (`isSolved`); FINISH runs the same sweep. The script says which, and the test holds it to that (`Ends with: FINISH`).
  **Issue:** #116
- **Decision:** `test/qa/a11y_sweep_test.dart` reads the move lines back out of `qa/a11y-sweep.md` and matches each against the legal moves, instead of re-running the searches as `listening_test.dart` does; it is tagged `guard` with mutations #116a–e. `spider_search.dart` stays in `integration_test/support/` and is imported from `test/qa/`.
  **Why:** a beam search per test run would add seconds to every mutation in the battery; reading the script also makes it the single source of the deal numbers.
  **Issue:** #116
- **Decision:** The replay sends TalkBack's taps as the board's semantics send them, with no time, and every double-tap line — the staged stock refusals included — must do what it says; a line that needs the Actions menu instead is a `[TalkBack]` bug. The replay's first run found two misfires, which #162 fixed on 2026-09-30 (fbde1b6). Announcement kinds the wins do not reach are staged in listed steps; test-plan Deals gained D10 and D11 for the greyscale stock hints.
  **Why:** the replay should match what TalkBack really sends, so a regression of #162 fails it.
  **Issue:** #116, #162
- **Decision:** Filed and fixed #160 (sev:medium) from #114's layout sweep. `LinkText` sizes to its label, and the About screens' `·` separator sits in one `Row` with the link after it. The defect was on every width, not only 320 dp.
  **Why:** the design has both link rows inline; the fix is small, and a medium bug left in M6 blocks `tools/m6_gate.sh`.
  **Issue:** #160, #114
- **Decision:** Filed and fixed #162 (sev:high) from #116's replay. Board semantics taps and TalkBack's DEAL activation carried time zero, so a second activation read as a double tap and Spider's stock was debounced. Tap time is now `Duration?`, and null never pairs or debounces. A device check on the emulator's Google TalkBack with v0.2.0 did **not** reproduce the stock half: both activations dealt. Recorded on #162; the Samsung TalkBack check is part of the owner's #116 sweep.
  **Why:** the fix is correct for every activation that arrives as a semantics tap, and it leaves pointer taps unchanged.
  **Issue:** #162, #116
- **Decision:** Filed #161 (`needs-triage`, not fixed in M6). In a debug build on the API 24 emulator, the winnable search's 5 s choice never appeared while one solve ran over 90 s. The v0.2.0 release build found a deal within 3 s on the same emulator. #114's sweep now screenshots the loading screen and cancels it.
  **Why:** not reproduced in a release build, and outside #114's scope (layout).
  **Issue:** #161, #114
- **Decision:** #114's API 24 core-check walk-through (release v0.2.0 by adb) was delegated to a background agent in its own worktree. My own runs cover the rest: `tools/e2e.sh` (PASSED on API 24), `tools/layout.sh` (both fonts PASSED on 320 dp after #160 was found), and the release install and cold start.
  **Why:** the walk-through is long and screenshot-heavy; delegating it kept this run's context for the fixes.
  **Issue:** #114
- **Decision:** `tools/m6_gate.sh` counts an open bug with no severity label as a blocker ("not known to be minor"), in addition to the plan's three kinds. #136 (M2, sev:low, not `confirmed`) was not moved into M6, since the plan moves confirmed M2–M5 bugs only.
  **Why:** the same rule as `/n8-verify`'s gate: an unrated bug is not known to be minor.
  **Issue:** #118
