# Run record — 2026-09-30, emu-api24, agent

- Build: v0.2.0 · BUILD 1021
- Device: Android SDK built for arm64 (AVD solitaire-api24, Nexus S profile, 640×1136 px at 320 dpi)
- Android / One UI: 7.0 (API 24)
- Hardware or emulator: emulator
- AVD and image: solitaire-api24, system-images;android-24;google_apis;arm64-v8a
- Runs: R1, R2, R3, R5, R6, R7 by their game options (Draw 3 · Standard · Timed; Draw 1 · Vegas · Untimed; Draw 1 · None · Timed; Spider One suit · Strict · Timed; Two suits · Relaxed; Four suits · Relaxed), with Settings set per check rather than held per row; every deal D1–D9
- Run by: agent

The release build, installed with `tools/install_build.sh v0.2.0 --device
emulator-5556` (versionName 0.2.0, versionCode 1021), driven by `adb shell
input` and judged from `adb exec-out screencap` and `uiautomator dump`.
Animation scales 1, font scale 1.0, Large cards off unless a note says
otherwise. This is an emulator result, not a device result.

Results are `pass`, `fail`, `skip`, `blocked` or `n-a`. A `fail` names its
issue in `bug`; a `blocked` names what blocked it.

| check | result | bug |
|---|---|---|
| T001 | pass | — |
| T011 | pass | — |
| T012 | pass | — |
| T013 | pass | — |
| T014 | pass | — |
| T102 | pass | — |
| T103 | pass | — |
| T104 | fail | #165 |
| T106 | pass | — |
| T107 | fail | #154 |
| T108 | pass | — |
| T121 | pass | — |
| T122 | pass | — |
| T123 | pass | — |
| T124 | fail | #154 |
| T125 | pass | — |
| T140 | pass | — |
| T141 | pass | — |
| T142 | n-a | — |
| T143 | skip | — |
| T144 | pass | — |
| T201 | pass | — |
| T202 | pass | — |
| T203 | pass | — |
| T204 | pass | — |
| T205 | pass | — |
| T206 | pass | — |
| T207 | pass | — |
| T208 | pass | — |
| T209 | pass | — |
| T210 | pass | — |
| T211 | pass | — |
| T212 | pass | — |
| T213 | pass | — |
| T214 | pass | — |
| T215 | pass | — |
| T216 | pass | — |
| T301 | pass | — |
| T302 | pass | — |
| T303 | pass | — |
| T304 | pass | — |
| T305 | pass | — |
| T306 | pass | — |
| T307 | pass | — |
| T308 | pass | — |
| T401 | pass | — |
| T402 | pass | — |
| T403 | pass | — |
| T404 | pass | — |
| T405 | pass | — |
| T406 | pass | — |
| T407 | fail | #152 |
| T408 | fail | #152 |
| T409 | pass | — |
| T410 | pass | — |
| T411 | pass | — |
| T413 | pass | — |
| T501 | pass | — |
| T502 | pass | — |
| T503 | pass | — |
| T504 | pass | — |
| T505 | pass | — |
| T603 | pass | — |
| T610 | pass | — |
| T611 | pass | — |
| T612 | pass | — |
| T613 | pass | — |
| T614 | pass | — |
| T702 | pass | — |
| T711 | fail | #160 |
| T712 | pass | — |
| T721 | fail | #160 |
| T722 | fail | #153 |
| T901 | pass | — |
| T902 | pass | — |
| T903 | pass | — |
| T904 | pass | — |
| T905 | blocked | adb input on API 24 cannot hold then move, and no column was crowded — note 6 |
| T801 | fail | #159 |
| T802 | fail | #159 |
| T803 | pass | — |
| T804 | pass | — |
| T805 | pass | — |
| T806 | pass | — |
| T807 | pass | — |
| T810 | n-a | — |

## Notes

Screenshots named below were taken in this run and kept under
`build/qa114-walk/` on the development machine; they are not committed.

**Failures.**

1. T104 (#165): with the on-screen keyboard up, the Deal number
   field sits under the keyboard and the screen does not scroll it into
   view, so the digits being typed, and T105's "Enter 1 to 999999" under
   the field, cannot be seen; the screen will not scroll further while the
   keyboard is up. The rest of T104's Expected holds: Random deal selected,
   Winnable only disabled with "A chosen deal can't be promised winnable",
   and clearing the field restores Winnable only. Seen twice, on New
   Klondike (`t104-typed.png`, `kb-recheck.png`). Not specific to the
   568-dp height: #165's widget test fails the same way at 384×824 dp.
2. T107, T124 (#154): "Keep playing the current game" is outlined and
   labelled in the default grey-blue on both setup screens, not teal or
   violet (`t107-keep.png`, `t124-keep2.png`); tapping it returns to the
   board unpaused, as expected. v0.2.0 predates the fix (a386cd0).
3. T407, T408 (#152): a Klondike win through auto-finish, and one through
   FINISH, shows the win card but is not recorded (Statistics unchanged at
   2 played, 1 won), and the menu then offers "Continue Klondike, draw 1,
   105 moves", which resumes the pre-finish board with FINISH lit
   (`t407-menu.png`, `t407-continue.png`, `t408-menu.png`,
   `t408-recheck.png`). A later deal over that board recorded it as a loss
   with its pre-finish Vegas score (+$13), which is why the Vegas lifetime
   total below is −$39. A win whose last card was placed by hand (all 144
   moves, Auto-finish off, no FINISH) was recorded correctly (T409, T502).
   v0.2.0 predates the fix (3d43956).
4. T711, T721 (#160): on both About screens the two link rows are stacked
   with the separator dot alone on a line between them (`t711-links.png`,
   `t721-links.png`). The links themselves open the right pages:
   honestarcade.app/, github.com/honestarcade/HonestSolitaire,
   honestarcade.app/contribute, and back returns to the app. The emulator
   has no browser; links open in the WebView Browser Tester
   (`org.chromium.webview_shell`), whose address bar gave the URLs.
5. T722 (#153): About Honest Arcade's SOURCE ON GITHUB opens
   https://github.com/honestarcade, the organisation page; seen twice
   (`t722-gh.png`). v0.2.0 predates the fix (49a74c3).
6. T801, T802 (#159): the play time since the last move is lost when the
   app is killed. Klondike Draw 3 · Standard · Timed: 16 s on the clock,
   swiped away from recents, Continue showed 0:00 (again 12 s → 0:00 on a
   re-check; `t801-timed-after.png`). Spider Four suits · Relaxed · Timed:
   left through Main menu at 20 s, force-stopped, Continue showed 10 s, the
   time of the last move (again after 42 s of play). Board, rows left,
   moves and score came back exactly, and UNDO stepped back the last move.
   v0.2.0 predates the fix (613ff1c).

**Findings outside the core checks, filed 2026-09-30.**

7. #164: Spider's empty stock (after the last row is dealt) reads "EMPT" / "Y",
   the word broken across two lines and spilling out of the slot, with
   Large cards on and off (`large-spider.png`, `normal-spider-empty.png`).
   Reached after T303's deals; T218 and T621 are the non-core checks
   nearest it.
8. #163: after a cold start, Continue restores the saved game but treats it as
   not yet started until the next move: the clock stays still (10 s held
   for 20 s, twice) and going to the home screen and back does not raise
   the pause card (`t402-return.png`). A warm Continue in the same session
   runs the clock, and after one move home-and-back pauses as T402 expects.
9. #166, T506 (not core): after a cold start with a Spider game saved
   ("Continue Spider" on the menu), Statistics opens on the Klondike tab
   (`t506-cold.png`); before the restart it opened on Spider.

**Not failures, with the reason.**

- T001: every capture showed READY with the bar full; SHUFFLING and
  DEALING passed faster than `screencap` could catch (about 0.2–0.3 s per
  frame on this emulator). The splash showed between about 0.5 s and 0.75 s
  going by the capture times, from which 600 ms can be neither proven nor
  ruled out; `test/ui/loading_screen_test.dart` holds the minimum.
- T140: every search found a deal before the count passed "1 deal tried".
  Winnable searches took about 1 s at Draw 1 and about 2 s at Draw 3.
- T143: skip; no search on this emulator ran long enough for the 5 s choice
  to appear.
- T204: selecting 7♣ and tapping 2♣ moved the selection to 2♣ instead of
  shaking; that is the designed rule (a selectable target takes the
  selection), and a non-selectable target (an empty foundation) shook and
  cleared as expected.
- T207: in a Timed game with accumulated time penalty the +10 for a
  foundation card left the score at 0, because the penalty is kept as a
  debt below the floor. Checked in an Untimed Standard game instead:
  +5 uncover, +5 waste to column, +10 to foundation.
- T215: the sweep had finished by the first capture, so "card by card" was
  seen only on the FINISH sweep (T214), which ran card by card and cascaded.
- T216: back from NEW returns to the board with the pause card up; the
  widget test expects that pause (`test/ui/pause_win_complete_test.dart`).
- T411: the win card read GAME COMPLETE, "All eight runs home"; the Kings'
  cascade had finished before the first capture.
- T503: BY DRAW MODE and BY SUIT COUNT show "won / played · %" and Vegas a
  lifetime total; no Vegas game set HIGH SCORE, but no Vegas win could be
  recorded (#152), so a Vegas win's effect is untested here.
- T902: double-tap sent A♠ (D4) to its foundation and a 9♥–8♥ run to 10♥.
- T905: a press-and-move on a face-down card never dragged, and the waste's
  lower cards never dragged; the spread could not be shown because no
  column in this run was compressed, and adb input on API 24 cannot hold
  still and then move.
- T142: n-a, phone only. T810: n-a, its steps need `solitaire-dev` and a
  debug build for `run-as`; this record is a release build on
  `solitaire-api24`.

**Deals and numbers.** D1–D9 each laid out the tops the Deals table names
and HINT rang the named pairs (D1 7♦→8♣, D4 A♠→foundation, D7 7♠→8♠,
D8 8♥→9♥, D9 8♣→9♣); D3 raised "No moves left". D5 (deal 1, Draw 1,
Standard, Timed) was won by hand in 144 moves, 7:39, score 2,144 with a
+1,525 time bonus. Spider deal 1000 (One suit, Strict, Timed) was won in
99 moves, 6:13, score 3,077 with a +1,876 time bonus; a completed run took
the score from 486 to 585. The winning lines came from the engine's solver
(Klondike) and `integration_test/support/spider_search.dart`'s beam search
(Spider), played by taps.

## Automated evidence

- `tools/e2e.sh --avd solitaire-api24`, 2026-09-30, `build/e2e/2026-09-30-1.log`
  in the main checkout (key lines: Klondike phase 1 `E2E_ELAPSED_MS=7568`,
  `+1: All tests passed!`; phase 2 `02:16 +1: All tests passed!`; Spider
  phase 1 `E2E_ELAPSED_MS=4031`, `+1: All tests passed!`; phase 2
  `01:20 +1: All tests passed!`; `PASSED`): PASSED on a debug build of d731eea (Klondike deal
  1000 and Spider deal 1000 played through undo, a refused move, HINT,
  background plus force-stop, a win and Statistics). That build carries the
  fixes for #152, #153, #154, #159 and #160, so it does not stand for
  v0.2.0; every check above was run by hand on the release build, and the
  e2e run corroborates the passes it overlaps.
- `tools/layout.sh --avd solitaire-api24`, `build/layout/2026-09-30-emu-api24-4/`:
  every screen at font scale 1.0 and 1.3 with Large cards off and on, no
  overflow and no ellipsis outside the board title; its one finding is #160.
  This run did not vary the font scale and relies on that sweep for 1.3.
  That directory's screenshots, listed on 2026-09-30, show no screen with
  the keyboard up and the Spider board only at the deal, so notes 1 and 7
  are states the sweep did not reach.
