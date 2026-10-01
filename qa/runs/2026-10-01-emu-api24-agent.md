# Run record — 2026-10-01, emu-api24, agent

- Build: v0.2.1 · BUILD 1031
- Device: Android SDK built for arm64 (AVD solitaire-api24, Nexus S profile, 640×1136 px at 320 dpi)
- Android / One UI: 7.0 (API 24)
- Hardware or emulator: emulator
- AVD and image: solitaire-api24, system-images;android-24;google_apis;arm64-v8a
- Runs: re-check of 2026-09-30-emu-api24-agent's failures
- Run by: agent

The release build, installed with `tools/install_build.sh v0.2.1 --device
emulator-5556` (`dumpsys package`: versionName 0.2.1, versionCode 1031) over
fresh app data, driven by `adb shell input` and judged from `adb exec-out
screencap` and `uiautomator dump`. Animation scales 1, font scale 1.0, Large
cards off unless a note says otherwise. This is an emulator result, not a
device result.

Results are `pass`, `fail`, `skip`, `blocked` or `n-a`. A `fail` names its
issue in `bug`; a `blocked` names what blocked it. Every row below re-checks
a failure of the earlier record, so its `bug` column names the issue it
re-checks.

| check | result | bug |
|---|---|---|
| T104 | pass | #165 |
| T107 | pass | #154 |
| T124 | pass | #154 |
| T407 | pass | #152 |
| T408 | pass | #152 |
| T711 | pass | #160 |
| T721 | pass | #160 |
| T722 | pass | #153 |
| T801 | pass | #159 |
| T802 | pass | #159 |

## Notes

The failures re-checked here are those of
`qa/runs/2026-09-30-emu-api24-agent.md` (v0.2.0 · BUILD 1021), its notes
1–6, and the findings of its notes 7–9. Screenshots named below were taken
in this run and kept under `build/qa118/` on the development machine; they
are not committed.

**Re-checked checks.**

1. T104 (#165): on New Klondike, with Winnable only chosen, the Deal number
   field scrolled into view above the keyboard while 48213 was typed: the
   digits showed, Random deal was selected, Winnable only was disabled with
   "A chosen deal can't be promised winnable", and the field's ✕ restored
   Winnable only (`t104-typed.png`, `t104-cleared.png`). With "0" typed,
   "Enter 1 to 999999" showed under the field, above the keyboard, on New
   Klondike and on New Spider (`t105-zero.png`, `t104-spider-zero.png`);
   with the keyboard closed the Deal button was disabled.
2. T107, T124 (#154): "Keep playing the current game" is outlined, tinted
   and labelled in teal on New Klondike and in violet on New Spider, under
   the filled Deal button (`t107-keep.png`, `t124-keep.png`); each returned
   to its board with the clock running.
3. T407, T408 (#152): Klondike deal 2982 (Draw 1, Standard, Timed),
   One-tap move off. T408 first: Auto-finish off, `qa/a11y-sweep.md`'s 35
   lines, then FINISH: the win card read 122 moves, 4:29, 3,191
   (`t408-win.png`). T407: Auto-finish on, the same 35 lines and 38 more
   that empty the stock and waste (a best-first search over the engine,
   2026-10-01, `build/qa118/find_line.dart`), after which the sweep started
   by itself: the win card read 115 moves, 8:32, 1,990 (`t407-win.png`).
   After each, Main menu showed "New game" with no Continue, and stayed so
   after a force stop; Statistics went from no games to 1 played, 1 won
   (`t408-stats.png`), then to 2 played, 2 won, Draw one 2 won of 2
   (`t407-stats.png`).
4. T711, T721 (#160): both About screens show their link rows on one line,
   "MADE BY HONEST ARCADE ↗ · SOURCE ON GITHUB ↗" and
   "HONESTARCADE.APP ↗ · SOURCE ON GITHUB ↗", with no dot alone
   (`t711-links.png`, `t721-links.png`). The links opened
   https://honestarcade.app/, https://github.com/honestarcade/HonestSolitaire
   and https://honestarcade.app/contribute in the WebView Browser Tester
   (`org.chromium.webview_shell`; the emulator has no other browser), read
   from its address bar, and back returned to the app each time.
5. T722 (#153): About Honest Arcade's SOURCE ON GITHUB opened
   https://github.com/honestarcade/HonestSolitaire (`t722-gh.png`).
6. T801 (#159): Klondike deal 48213, Draw 3 · Standard · Timed, three moves,
   then no move for about 40 s; the clock read 46 s about 2 s before the
   app was dismissed from recents, and its process was gone afterwards. A
   sideways `adb shell input swipe` on the recents card did not dismiss it,
   so the card's ✕ (Dismiss Honest Solitaire) was used, which removes the
   task as a swipe does.
   Continue Klondike, read about 1 s later, showed 51 s with the same board,
   3 moves and score 0 (`t801-after.png`); UNDO returned the last draw to
   the stock (`t801-undo.png`).
7. T802 (#159): Spider deal 1000, One suit · Strict · Timed, two moves,
   then 20 s with no move; 57 s on the clock about 2 s before Home, then
   force stop. Continue Spider showed 59 s, 2 moves, score 498, 5 deals
   left and the same column tops (`t802-before.png`, `t802-after.png`).
   Again through Pause → Main menu: 3:21 on the clock, about 17 s more
   play, force stop, and Continue showed 3:42 about 2 s after the tap.

**Findings re-checked.**

8. #163: pass. After a cold start, Continue Spider ran the clock at once
   (59 s to 1:10 over about 11 s with no move) and Home then back raised the
   pause card, its clock held at 1:19 (`t163-running.png`,
   `t163-return.png`). The same held for Continue Klondike after a force
   stop (1:24 to 1:36 over 10 s, then the pause card at 1:36,
   `t163-klondike-return.png`); the clock did not move in 20 s in the
   background.
9. #164, #171: fail, re-checked once. After Spider's last row was dealt the
   stock reads EMPTY on one line, in the mono caps, readable in the capture
   (`t164-empty.png`), so the word no longer breaks. It is not wholly inside
   its slot: the letters fill the slot's full width, and the Y's right arm
   lies on the slot's right border (pixel columns 615–616 of
   `t164-empty.png` hold both the border and the Y; zoomed in
   `t164-empty-zoom.png`), while the E clears the left border by 3 px. The
   capital letters are 9 px tall, 4.5 dp, measured on that screenshot.
   Unchanged after leaving and returning (`t164-empty-recheck.png`) and with
   Large cards on (`t164-empty-large.png`).
10. #166 (T506): pass. After a cold start with Spider saved ("Continue
    Spider, 1 suit, 2 moves" on the menu), Statistics opened on the Spider
    tab (`t506-cold.png`), and How to play on the Spider tab
    (`howto-cold.png`).
