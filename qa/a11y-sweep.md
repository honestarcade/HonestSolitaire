# Accessibility sweep (#116)

The phone's accessibility settings, one at a time, on the owner's Samsung
Galaxy S26 Ultra: TalkBack plays both games, then the largest font and
display size, then Remove animations, then Greyscale. It is written for a
sighted owner: you watch the screen and listen, and say what you see and
hear.

The checks are `### A<nn> — title`, each with `Steps:`, `Expected:` and
`Related:` (the checks in `qa/test-plan.md` that cover the same ground
without the accessibility setting). The sweep gets one run record,
`qa/runs/YYYY-MM-DD-s26ultra-owner.md`, copied from `qa/runs/TEMPLATE.md`,
with one row per A-check. You report in chat; the agent transcribes and
files the bugs.

The deals and move lines below are not typed by hand.
`dart run tools/find_a11y_deals.dart` found the deals (the Klondike deal
with the fewest moves before FINISH is offered, by the app's own solver; the
one-suit Spider deal with the fewest moves to a win that its search found)
and printed the lines. `test/qa/a11y_sweep_test.dart` reads every line back
out of this file and plays it through the game the way TalkBack does — a
double-tap on each node, or the named action — and fails if a line is not a
legal move, is not worded as the app will say it, or does not end where this
script says it ends.

## Failures

Write down only what fails. A failure is any of:

- **Double read** — the same node read twice in one swipe.
- **Wrong order** — focus jumps out of the reading order: top bar, then the
  top row left to right, then the columns left to right and each top to
  bottom, then the tool row.
- **Unreachable node** — a control or card that swiping never lands on, or
  that double-tap does not act on.
- **Face-down card named** — any rank or suit read for a face-down card.
  Face-down cards are one node per column: "Column 3, 4 face-down cards".
- **Wrong or missing announcement** — what TalkBack says differs from the
  words in quotes below, or says nothing where a quote is given.

For each failure, screenshot TalkBack's speech caption (the "Display speech
output" setting below puts it on screen) and say which step it was. If the
same thing happens in one of Google's own apps (Settings, Clock), it is a
TalkBack quirk: it is noted in the record, not filed.

## Before you start

### A01 — Record the versions and the settings you will change
Steps:
- Settings → About phone → Software information: note the One UI version and the Android version.
- Settings → Accessibility → TalkBack → Settings → About TalkBack: note the TalkBack version.
- In Honest Solitaire, Settings: note the version line at the bottom (the build).
- Note the current value of each phone setting this sweep changes: TalkBack (on/off), Settings → Display → Font size and style → Font size (which step), Settings → Display → Screen zoom (which step), Settings → Accessibility → Vision enhancements (Visibility enhancements on older One UI) → Remove animations, and the same menu's Colour adjustment (off, or which filter). Screenshots are fine.
- Note Honest Solitaire's own Settings as they are now (one screenshot of the whole list).
Expected: Every value above is written down (or screenshotted) before anything is changed, and each is put back at the end of its part of the sweep (A16, A24, A35, A43).
Related: T601
Where: phone

**Honest Solitaire's Settings during the whole sweep:** One-tap move on,
Auto-finish on, Auto-flip cards on, Unlimited undo on, Winnable deals only
off, Left-handed layout off, Large cards off (A23 turns it on for one
board), Show timer on, Show moves and score on, Card animations on, Sound
effects off, Background music off, Haptics on. A setup screen's options are
given in each check; a typed deal number always deals exactly that deal.

If the agent has the phone on adb, it reads the settings back itself
(`settings get system font_scale`, `wm density`, `settings get secure
enabled_accessibility_services`) instead of asking for screenshots.

## TalkBack

TalkBack gestures used below: **swipe right / left** moves to the next /
previous item; **double-tap** anywhere acts on the item in focus; **Actions**
opens the list of actions the focused item offers (on current TalkBack,
open the TalkBack menu — tap with three fingers, or swipe down then right —
and choose Actions). A02 checks which of these your TalkBack uses; the
record notes it. You can also touch an item to put focus on it.

With TalkBack on, a double-tap on a card **selects** it (you hear "…
selected"), even with One-tap move on; a double-tap on another pile then
moves it there.

### A02 — TalkBack on, its speech on screen, and the Actions gesture
Steps:
- Settings → Accessibility → TalkBack → on.
- TalkBack → Settings → Advanced settings → Developer settings → Display speech output → on.
- In Settings, put focus on any list item with an Actions entry (a notification works) and open Actions as described above.
Expected: TalkBack speaks and its words appear as captions on screen; the Actions list opens with the gesture you will use below.
Related: T001
Where: phone

### A03 — The splash and the menu
Steps:
- Force stop Honest Solitaire (Settings → Apps → Honest Solitaire → Force stop) and open it from its icon.
- On the menu, swipe right through every item, then back left to the first.
Expected: The menu reads "Honest Solitaire, by Honest Arcade, no ads" and then, each as a button, "Klondike, Draw 1 or 3 · four foundations", "Spider, 1, 2 or 4 suits · ten columns" (or Continue, when a game is saved), "Statistics", "How to play", "Settings" and "About Honest Arcade, no ads, no tracking, open source", in screen order, with no double reads.
Related: T001, T010
Where: phone

### A04 — New Klondike, and typing a deal number
Steps:
- Double-tap the Klondike button.
- Swipe through the screen; double-tap "Cards per draw, Draw 1", "Scoring, Standard" and "Timer, Untimed".
- Double-tap "Deal number, optional" and type **2982** on TalkBack's keyboard; close the keyboard.
- Swipe to "Deal" (do not double-tap it yet).
Expected: Each option reads its group and value, and "selected" on the one chosen; the chosen one changes when you double-tap another. The deal-number field reads its label and what you typed; the deal choice reads that a typed number deals Random. "Deal" reads as an enabled button.
Related: T101, T104, T106
Where: phone

### A05 — Deal 2982 opens, and the board reads in order
Steps:
- Double-tap "Deal".
- From the top of the screen, swipe right through every item until the tool row's last button.
Expected: The board opening says "New deal". Then, in order: the top bar (the pause pill, "Pause, …" with the game's title, and the readouts), "Stock, 24 cards", "Waste, empty", the four foundations ("Spades foundation, empty" …), then column 1 to column 7, each column's face-down node first ("Column 2, 1 face-down card" … "Column 7, 6 face-down cards") and then its face-up card ("Queen of spades, column 1, top card" …), then "Undo" (disabled), "Hint", "Finish" (disabled), "Restart" and "New deal". No face-down node names a rank or suit.
Related: T201, T213
Where: phone

<!-- a11y-lines: klondike -->
### A06 — Every kind of result is announced (Klondike 2982)
Deal number **2982**: New Klondike, Draw 1, Standard, Untimed.

Steps:
- Double-tap "Hint": hear "Hint: ace of spades to spades foundation", and see the dashed amber rings.
- Double-tap "Ace of spades, column 7, top card": hear "Ace of spades selected". Double-tap "Column 7, 6 face-down cards": hear "Selection cleared".
- Double-tap "Ace of spades, column 7, top card", then "Column 2, 1 face-down card": hear "Can't move there"; nothing moves.
- Double-tap "Stock, 24 cards": hear "Drew eight of hearts". Double-tap "Undo": hear "Undone".
- Double-tap "Ace of spades, column 7, top card" to select it, then double-tap the same card again. If the ace moved, double-tap "Undo" so the board is back at the deal.
Expected: Each quoted phrase is heard at its step and the board changes only where a step says so. The last step says "Selection cleared" and leaves the ace in column 7 — the re-tap that clears a selection (#108). A replay of that step through the game controller with TalkBack's taps (agent, 2026-09-30) sent the ace to its foundation instead; if the phone does the same, it is a `[TalkBack]` bug.
Related: T204, T212, T213
Where: phone

### A07 — Win deal 2982 by TalkBack, lines 1–35
Steps:
- From the deal, play each line below in order. "Double-tap A, then B" means put focus on A and double-tap (you hear A's run "… selected"), then on B and double-tap. "On A, Actions → B" means put focus on A, open Actions and choose B. A line with a single double-tap is a stock tap.
- After each line, check the words you hear.
- Line 25 starts on the card node you double-tapped last (line 23's destination). If its first double-tap does anything but select "Five of spades and 1 more", note what happened, double-tap "Undo" if a card moved, and make the move by Actions instead: On "Five of spades, column 7, 2nd from top", Actions → "Move to column 2".
Expected: Every line does what it says and TalkBack says the words after "hear" (move, then any card turned). Line 25's first double-tap selects, as any other would: the board takes two TalkBack activations of the same node as one double tap however far apart they are, which a replay through the game controller found would misfire there (agent, 2026-09-30), and that is a `[TalkBack]` bug. After line 35 every tableau card is face up and "Finish" reads as enabled; Auto-finish does not start by itself, because the stock still holds cards.

1. Double-tap "Ace of spades, column 7, top card", then "Spades foundation, empty" — hear "Ace of spades to spades foundation. Card turned: jack of diamonds"
2. On "Eight of spades, column 6, top card", Actions → "Move to column 4" — hear "Eight of spades to column 4. Card turned: six of diamonds"
3. Double-tap "Jack of diamonds, column 7, top card", then "Queen of spades, column 1, top card" — hear "Jack of diamonds to column 1. Card turned: queen of hearts"
4. On "Nine of hearts, column 4, 2nd from top", Actions → "Move to column 3" — hear "Nine of hearts and 1 more to column 3. Card turned: eight of clubs"
5. Double-tap "Ten of clubs, column 3, 3rd from top", then "Jack of diamonds, column 1, top card" — hear "Ten of clubs and 2 more to column 1. Card turned: ace of hearts"
6. On "Ace of hearts, column 3, top card", Actions → "Move to hearts foundation" — hear "Ace of hearts to hearts foundation. Card turned: seven of spades"
7. Double-tap "Six of diamonds, column 6, top card", then "Seven of spades, column 3, top card" — hear "Six of diamonds to column 3. Card turned: ace of diamonds"
8. On "Ace of diamonds, column 6, top card", Actions → "Move to diamonds foundation" — hear "Ace of diamonds to diamonds foundation. Card turned: seven of diamonds"
9. Double-tap "Seven of diamonds, column 6, top card", then "Eight of spades, column 1, top card" — hear "Seven of diamonds to column 1. Card turned: six of hearts"
10. On "Stock, 24 cards", Actions → "Draw" — hear "Drew eight of hearts"
11. Double-tap "Eight of hearts, waste, top card", then "Nine of clubs, column 2, top card" — hear "Eight of hearts to column 2"
12. On "Stock, 23 cards", Actions → "Draw" — hear "Drew four of diamonds"
13. Double-tap "Stock, 22 cards" — hear "Drew five of hearts"
14. On "Stock, 21 cards", Actions → "Draw" — hear "Drew king of diamonds"
15. Double-tap "Stock, 20 cards" — hear "Drew three of hearts"
16. On "Stock, 19 cards", Actions → "Draw" — hear "Drew jack of clubs"
17. Double-tap "Jack of clubs, waste, top card", then "Queen of hearts, column 7, top card" — hear "Jack of clubs to column 7"
18. On "Stock, 18 cards", Actions → "Draw" — hear "Drew nine of spades"
19. Double-tap "Stock, 17 cards" — hear "Drew seven of clubs"
20. On "Seven of clubs, waste, top card", Actions → "Move to column 2" — hear "Seven of clubs to column 2"
21. Double-tap "Six of hearts, column 6, top card", then "Seven of clubs, column 2, top card" — hear "Six of hearts to column 2. Card turned: king of clubs"
22. On "Queen of hearts, column 7, 2nd from top", Actions → "Move to column 6" — hear "Queen of hearts and 1 more to column 6. Card turned: five of spades"
23. Double-tap "Four of hearts, column 5, top card", then "Five of spades, column 7, top card" — hear "Four of hearts to column 7. Card turned: two of hearts"
24. On "Two of hearts, column 5, top card", Actions → "Move to hearts foundation" — hear "Two of hearts to hearts foundation. Card turned: ten of diamonds"
25. Double-tap "Five of spades, column 7, 2nd from top", then "Six of hearts, column 2, top card" — hear "Five of spades and 1 more to column 2. Card turned: nine of diamonds"
26. On "Eight of clubs, column 4, top card", Actions → "Move to column 7" — hear "Eight of clubs to column 7. Card turned: eight of diamonds"
27. Double-tap "Ten of diamonds, column 5, top card", then "Jack of clubs, column 6, top card" — hear "Ten of diamonds to column 6. Card turned: ten of spades"
28. On "Nine of diamonds, column 7, 2nd from top", Actions → "Move to column 5" — hear "Nine of diamonds and 1 more to column 5. Card turned: six of clubs"
29. Double-tap "Nine of clubs, column 2, 6th from top", then "Ten of diamonds, column 6, top card" — hear "Nine of clubs and 5 more to column 6. Card turned: jack of hearts"
30. On "Ten of spades, column 5, 3rd from top", Actions → "Move to column 2" — hear "Ten of spades and 2 more to column 2. Card turned: five of diamonds"
31. Double-tap "Six of clubs, column 7, top card", then "Seven of diamonds, column 1, top card" — hear "Six of clubs to column 1. Card turned: ten of hearts"
32. On "Nine of spades, waste, top card", Actions → "Move to column 7" — hear "Nine of spades to column 7"
33. Double-tap "Three of hearts, waste, top card", then "Hearts foundation, up to two" — hear "Three of hearts to hearts foundation"
34. On "Four of hearts, column 6, top card", Actions → "Move to hearts foundation" — hear "Four of hearts to hearts foundation"
35. Double-tap "Eight of diamonds, column 4, top card", then "Nine of spades, column 7, top card" — hear "Eight of diamonds to column 7. Card turned: three of spades"

Watch: line 25
Ends with: FINISH
Related: T204, T205, T203
Where: phone

### A08 — Recycle, then FINISH and the win card
Steps:
- Double-tap "Stock, 16 cards" sixteen times, until it reads "Stock, empty, double-tap to recycle"; double-tap it once more.
- Double-tap "Finish".
- Swipe through the win card and double-tap "Main menu".
Expected: Each stock tap says "Drew …"; the recycle says "Stock recycled" and "Finish" stays enabled. FINISH says "Finishing", the cards sweep up, and "Game complete" is read once, with the win card's figures and "New deal", "See statistics" and "Main menu". The menu offers no Continue for this game, and Statistics shows the win.
Related: T214, T406, T407, T408
Where: phone
<!-- /a11y-lines -->

### A09 — No moves left, Restart and Pause (Klondike 71)
Steps:
- New Klondike: Draw 3, Standard, Untimed, deal number **71**; double-tap "Deal".
- Double-tap "Hint".
- Double-tap "Restart".
- Double-tap the pause pill ("Pause, …").
- Swipe through the pause card; double-tap "Resume".
Expected: The board opening says "New deal". HINT says "No moves left", and the banner reads with its "Undo" (disabled) and "New deal" buttons. RESTART says "Restarted". The pause pill says "Paused", the pause card reads its mode line and "Resume", "Restart this deal", "New deal", "Rules", "Settings" and "Main menu", and nothing on the board behind it is reachable. Resume returns focus to the board.
Related: T413, T216, T401
Where: phone

### A10 — The pause card's Rules and Settings, and back
Steps:
- Pause again. Double-tap "Rules"; swipe through How to play; use the phone's back gesture.
- Double-tap "Settings"; swipe through every row; go back.
- Double-tap "Main menu".
Expected: How to play opens on the Klondike tab and reads its tabs ("Klondike", selected; "Spider") and text in order; back returns to the paused board. Settings reads each row as its label, its description and on/off (a switch), then the card backs ("Navy card back", selected …); back returns to the paused board. Main menu returns to the menu.
Related: T403, T601, T603, T701
Where: phone

<!-- a11y-lines: spider -->
### A11 — New Spider, and win deal 924 by TalkBack
Deal number **924**: New Spider, One suit, Strict, Untimed.

Steps:
- On the menu double-tap the Spider button. Double-tap "Suits in play, One suit…", the Strict empty-column choice and "Timer, Untimed"; type **924** in "Deal number, optional"; double-tap "Deal".
- Swipe once through the board, then play each line below as in A07. A single double-tap on the stock deals a row.
- After line 28 column 8 is empty with rows still to deal. Double-tap "Stock, 2 deals left" — hear "Can't deal: fill every column"; nothing changes. Then go on with line 29.
- After line 35 every row is dealt. Double-tap "Stock, no deals left" — hear "No deals left"; nothing changes. Then go on with line 36.
- Lines 23, 33 and 35 deal a row by double-tapping the stock after line 11 already did. The board ignores a second stock tap within 0.3 s of a deal (#137), and a TalkBack double-tap reaches the app with no time, so it may take each of these as that second tap and do nothing — and the two staged stock taps above with them. If a stock double-tap is silent and the count does not drop, note it and deal by Actions instead:
  - line 23: On "Stock, 3 deals left", Actions → "Deal a row"
  - line 33: On "Stock, 2 deals left", Actions → "Deal a row"
  - line 35: On "Stock, 1 deal left", Actions → "Deal a row"
- Lines 53, 65 and 81 start on the card node you double-tapped last, as line 25 of the Klondike win does (A07). If a first double-tap does anything but select, note it, double-tap "Undo" if a card moved, and make that move by Actions instead:
  - line 53: On "Queen of spades, column 2, 11th from top", Actions → "Move to column 1"
  - line 65: On "Queen of spades, column 4, 12th from top", Actions → "Move to column 7"
  - line 81: On "Eight of spades, column 4, 2nd from top", Actions → "Move to column 3"
Expected: The setup options read with their states, as in A04. The board opening says "New deal", the stock reads "Stock, 5 deals left", the completed slot "Completed runs, 0 of 8", and the tool row's deal button "Deal, 5 left". Every line does what it says and TalkBack says the words after "hear"; a completed run adds "Run completed, spades", and the completed slot then reads one more of 8. The two staged stock taps are refused with the words given and change nothing. Lines 23, 33 and 35 each deal a row, and lines 53, 65 and 81 select on their first double-tap (see A07); a line that needed its Actions fallback is a `[TalkBack]` bug. Spider has no FINISH: the last line completes the last run by hand and wins.

1. Double-tap "Jack of spades, column 2, top card", then "Queen of spades, column 10, top card" — hear "Jack of spades to column 10. Card turned: ten of spades"
2. On "Ten of spades, column 2, top card", Actions → "Move to column 10" — hear "Ten of spades to column 10. Card turned: seven of spades"
3. Double-tap "Nine of spades, column 5, top card", then "Ten of spades, column 10, top card" — hear "Nine of spades to column 10. Card turned: king of spades"
4. On "Eight of spades, column 6, top card", Actions → "Move to column 10" — hear "Eight of spades to column 10. Card turned: four of spades"
5. Double-tap "Queen of spades, column 10, 5th from top", then "King of spades, column 8, top card" — hear "Queen of spades and 4 more to column 8. Card turned: queen of spades"
6. On "Stock, 5 deals left", Actions → "Deal a row" — hear "Dealt a row, 4 left"
7. Double-tap "Six of spades, column 6, top card", then "Seven of spades, column 8, top card" — hear "Six of spades to column 8"
8. On "Five of spades, column 3, 2nd from top", Actions → "Move to column 8" — hear "Five of spades and 1 more to column 8. Card turned: nine of spades"
9. Double-tap "Four of spades, column 6, top card", then "Five of spades, column 2, top card" — hear "Four of spades to column 2. Card turned: six of spades"
10. On "Six of spades, column 6, top card", Actions → "Move to column 4" — hear "Six of spades to column 4. Card turned: ten of spades"
11. Double-tap "Stock, 4 deals left" — hear "Dealt a row, 3 left"
12. On "Two of spades, column 9, 2nd from top", Actions → "Move to column 8" — hear "Two of spades and 1 more to column 8. Card turned: jack of spades. Run completed, spades"
13. Double-tap "Five of spades, column 2, 3rd from top", then "Six of spades, column 5, top card" — hear "Five of spades and 2 more to column 5"
14. On "Six of spades, column 5, 4th from top", Actions → "Move to column 2" — hear "Six of spades and 3 more to column 2"
15. Double-tap "Seven of spades, column 2, 5th from top", then "Eight of spades, column 10, top card" — hear "Seven of spades and 4 more to column 10. Card turned: jack of spades"
16. On "Eight of spades, column 10, 6th from top", Actions → "Move to column 6" — hear "Eight of spades and 5 more to column 6"
17. Double-tap "Ten of spades, column 6, 8th from top", then "Jack of spades, column 2, top card" — hear "Ten of spades and 7 more to column 2. Card turned: seven of spades"
18. On "Jack of spades, column 2, 9th from top", Actions → "Move to column 5" — hear "Jack of spades and 8 more to column 5. Card turned: two of spades"
19. Double-tap "Ten of spades, column 1, top card", then "Jack of spades, column 8, top card" — hear "Ten of spades to column 8"
20. On "Two of spades, column 1, 2nd from top", Actions → "Move to column 5" — hear "Two of spades and 1 more to column 5. Card turned: five of spades. Card turned: three of spades. Run completed, spades"
21. Double-tap "Three of spades, column 5, top card", then "Four of spades, column 9, top card" — hear "Three of spades to column 9. Card turned: three of spades"
22. On "Four of spades, column 9, 2nd from top", Actions → "Move to column 1" — hear "Four of spades and 1 more to column 1. Card turned: six of spades"
23. Double-tap "Stock, 3 deals left" — hear "Dealt a row, 2 left"
24. On "Jack of spades, column 8, 3rd from top", Actions → "Move to column 9" — hear "Jack of spades and 2 more to column 9. Card turned: ace of spades"
25. Double-tap "Ace of spades, column 8, top card", then "Two of spades, column 1, top card" — hear "Ace of spades to column 1. Card turned: eight of spades"
26. On "Eight of spades, column 8, top card", Actions → "Move to column 9" — hear "Eight of spades to column 9. Card turned: six of spades"
27. Double-tap "Five of spades, column 1, 5th from top", then "Six of spades, column 8, top card" — hear "Five of spades and 4 more to column 8. Card turned: king of spades"
28. On "Six of spades, column 8, 6th from top", Actions → "Move to column 10" — hear "Six of spades and 5 more to column 10"
29. Double-tap "Seven of spades, column 10, 7th from top", then "Eight of spades, column 9, top card" — hear "Seven of spades and 6 more to column 9"
30. On "Queen of spades, column 9, 12th from top", Actions → "Move to column 1" — hear "Queen of spades and 11 more to column 1. Card turned: nine of spades. Run completed, spades"
31. Double-tap "Nine of spades, column 1, top card", then "Column 8, empty" — hear "Nine of spades to column 8. Card turned: queen of spades"
32. On "Queen of spades, column 1, top card", Actions → "Move to column 4" — hear "Queen of spades to column 4. Card turned: two of spades"
33. Double-tap "Stock, 2 deals left" — hear "Dealt a row, 1 left"
34. On "Six of spades, column 9, 2nd from top", Actions → "Move to column 8" — hear "Six of spades and 1 more to column 8. Card turned: jack of spades"
35. Double-tap "Stock, 1 deal left" — hear "Dealt a row, 0 left"
36. On "Eight of spades, column 4, top card", Actions → "Move to column 5" — hear "Eight of spades to column 5"
37. Double-tap "Seven of spades, column 8, 4th from top", then "Eight of spades, column 5, top card" — hear "Seven of spades and 3 more to column 5"
38. On "Nine of spades, column 5, 6th from top", Actions → "Move to column 2" — hear "Nine of spades and 5 more to column 2"
39. Double-tap "Ten of spades, column 2, 7th from top", then "Jack of spades, column 4, top card" — hear "Ten of spades and 6 more to column 4"
40. On "Three of spades, column 10, top card", Actions → "Move to column 4" — hear "Three of spades to column 4"
41. Double-tap "Eight of spades, column 3, top card", then "Nine of spades, column 8, top card" — hear "Eight of spades to column 8"
42. On "Seven of spades, column 3, top card", Actions → "Move to column 8" — hear "Seven of spades to column 8"
43. Double-tap "Five of spades, column 2, top card", then "Six of spades, column 3, top card" — hear "Five of spades to column 3"
44. On "Two of spades, column 2, top card", Actions → "Move to column 4" — hear "Two of spades to column 4"
45. Double-tap "Nine of spades, column 8, 3rd from top", then "Ten of spades, column 9, top card" — hear "Nine of spades and 2 more to column 9"
46. On "Six of spades, column 3, 2nd from top", Actions → "Move to column 9" — hear "Six of spades and 1 more to column 9"
47. Double-tap "Ace of spades, column 3, top card", then "Two of spades, column 4, top card" — hear "Ace of spades to column 4. Run completed, spades"
48. On "Four of spades, column 7, top card", Actions → "Move to column 9" — hear "Four of spades to column 9"
49. Double-tap "Three of spades, column 4, top card", then "Four of spades, column 9, top card" — hear "Three of spades to column 9"
50. On "Two of spades, column 2, top card", Actions → "Move to column 9" — hear "Two of spades to column 9. Card turned: queen of spades"
51. Double-tap "Jack of spades, column 9, 10th from top", then "Queen of spades, column 2, top card" — hear "Jack of spades and 9 more to column 2. Card turned: eight of spades"
52. On "Eight of spades, column 1, top card", Actions → "Move to column 3" — hear "Eight of spades to column 3"
53. Double-tap "Queen of spades, column 2, 11th from top", then "King of spades, column 1, top card" — hear "Queen of spades and 10 more to column 1"
54. On "Seven of spades, column 4, 2nd from top", Actions → "Move to column 3" — hear "Seven of spades and 1 more to column 3"
55. Double-tap "Ace of spades, column 4, top card", then "Two of spades, column 1, top card" — hear "Ace of spades to column 1. Card turned: queen of spades. Run completed, spades"
56. On "Five of spades, column 6, top card", Actions → "Move to column 3" — hear "Five of spades to column 3"
57. Double-tap "Four of spades, column 7, top card", then "Five of spades, column 3, top card" — hear "Four of spades to column 3"
58. On "Three of spades, column 7, top card", Actions → "Move to column 3" — hear "Three of spades to column 3"
59. Double-tap "Two of spades, column 1, top card", then "Three of spades, column 3, top card" — hear "Two of spades to column 3"
60. On "Ace of spades, column 7, top card", Actions → "Move to column 3" — hear "Ace of spades to column 3"
61. Double-tap "Nine of spades, column 3, 9th from top", then "Ten of spades, column 7, top card" — hear "Nine of spades and 8 more to column 7. Card turned: four of spades"
62. On "Ten of spades, column 7, 10th from top", Actions → "Move to column 10" — hear "Ten of spades and 9 more to column 10"
63. Double-tap "Jack of spades, column 10, 11th from top", then "Queen of spades, column 4, top card" — hear "Jack of spades and 10 more to column 4"
64. On "Ten of spades, column 7, top card", Actions → "Move to column 6" — hear "Ten of spades to column 6. Card turned: king of spades"
65. Double-tap "Queen of spades, column 4, 12th from top", then "King of spades, column 7, top card" — hear "Queen of spades and 11 more to column 7. Card turned: seven of spades. Card turned: king of spades. Run completed, spades"
66. On "Four of spades, column 10, top card", Actions → "Move to column 5" — hear "Four of spades to column 5"
67. Double-tap "Queen of spades, column 10, top card", then "King of spades, column 7, top card" — hear "Queen of spades to column 7. Card turned: nine of spades"
68. On "Nine of spades, column 10, top card", Actions → "Move to column 6" — hear "Nine of spades to column 6. Card turned: ace of spades"
69. Double-tap "Eight of spades, column 9, top card", then "Nine of spades, column 6, top card" — hear "Eight of spades to column 6. Card turned: jack of spades"
70. On "Seven of spades, column 4, top card", Actions → "Move to column 6" — hear "Seven of spades to column 6. Card turned: eight of spades"
71. Double-tap "Six of spades, column 5, 3rd from top", then "Seven of spades, column 6, top card" — hear "Six of spades and 2 more to column 6"
72. On "Jack of spades, column 6, 8th from top", Actions → "Move to column 7" — hear "Jack of spades and 7 more to column 7"
73. Double-tap "Three of spades, column 5, top card", then "Four of spades, column 7, top card" — hear "Three of spades to column 7. Card turned: three of spades"
74. On "Two of spades, column 6, top card", Actions → "Move to column 7" — hear "Two of spades to column 7"
75. Double-tap "Ace of spades, column 10, top card", then "Two of spades, column 7, top card" — hear "Ace of spades to column 7. Card turned: ten of spades. Card turned: ace of spades. Run completed, spades"
76. On "Three of spades, column 5, top card", Actions → "Move to column 3" — hear "Three of spades to column 3"
77. Double-tap "Ten of spades, column 7, top card", then "Jack of spades, column 9, top card" — hear "Ten of spades to column 9. Card turned: five of spades"
78. On "Four of spades, column 3, 2nd from top", Actions → "Move to column 7" — hear "Four of spades and 1 more to column 7. Card turned: queen of spades"
79. Double-tap "Seven of spades, column 6, top card", then "Eight of spades, column 4, top card" — hear "Seven of spades to column 4"
80. On "Queen of spades, column 3, top card", Actions → "Move to column 5, empty" — hear "Queen of spades to column 5. Card turned: nine of spades"
81. Double-tap "Eight of spades, column 4, 2nd from top", then "Nine of spades, column 3, top card" — hear "Eight of spades and 1 more to column 3. Card turned: six of spades"
82. On "Five of spades, column 7, 3rd from top", Actions → "Move to column 4" — hear "Five of spades and 2 more to column 4"
83. Double-tap "Six of spades, column 4, 4th from top", then "Seven of spades, column 3, top card" — hear "Six of spades and 3 more to column 3. Card turned: king of spades"
84. On "Nine of spades, column 3, 7th from top", Actions → "Move to column 9" — hear "Nine of spades and 6 more to column 9. Card turned: two of spades"
85. Double-tap "Two of spades, column 3, top card", then "Three of spades, column 9, top card" — hear "Two of spades to column 9"
86. On "Jack of spades, column 9, 10th from top", Actions → "Move to column 5" — hear "Jack of spades and 9 more to column 5"
87. Double-tap "Ace of spades, column 10, top card", then "Two of spades, column 5, top card" — hear "Ace of spades to column 5"
88. On "Queen of spades, column 5, 12th from top", Actions → "Move to column 4" — hear "Queen of spades and 11 more to column 4. Run completed, spades"

Watch: lines 23, 33, 35, 53, 65, 81
Ends with: the win
Related: T120, T303, T304, T306, T307
Where: phone
<!-- /a11y-lines -->

### A12 — The Spider win card, Statistics and back to the menu
Steps:
- Swipe through the win card; double-tap "See statistics".
- Swipe through Statistics; go back; double-tap "Main menu".
- On the menu open About Honest Arcade, swipe through it, and go back.
Expected: "Game complete" is read once with the win card; Statistics opens on the Spider tab ("Spider", selected) with the win counted and every figure read with its label; back returns to the win card; the menu offers no Continue for the won Spider. About Honest Arcade reads its text in order and its links as links; back returns to the menu.
Related: T411, T409, T502, T720
Where: phone

### A13 — TalkBack off
Steps:
- Turn TalkBack off (Settings → Accessibility → TalkBack, or the shortcut you use); put Display speech output back as noted in A01.
Expected: TalkBack is off and the phone is as A01 recorded it.
Related: T601
Where: phone

## Largest font and display size

"Largest" is the rightmost step of each slider. The app follows the phone's
font size up to 1.3× the normal size and no further (#106): above that step
it should look exactly as at that step.

### A20 — Font size and Screen zoom at their largest
Steps:
- Settings → Display → Font size and style → Font size: the rightmost step.
- Settings → Display → Screen zoom: the rightmost step.
- Read the screen's width: Developer options → Smallest width (in dp), or ask the agent to read it over adb (`wm size` and `wm density`).
Expected: The width is at least 320 dp. If it is less, step Screen zoom back one step at a time until it is at least 320 dp, and note the step used — that is the largest in-spec display size.
Related: T219, T414
Where: phone

### A21 — Every screen fits
Steps:
- Open each screen in turn: the menu, New Klondike, New Spider, a Klondike board, a Spider board, the pause card on each, Statistics (both tabs), Settings (scroll to the end), How to play (both tabs), About the App, About Honest Arcade; win or reach the win card once (deal 2982, lines above, by touch).
- Screenshot each.
Expected: No text is cut off, overlaps or runs off the screen; screens that scroll scroll to their end; the board's top bar and tool row keep their height, their labels shrink to fit rather than clip, and all columns are fully visible.
Related: T010, T101, T120, T201, T301, T401, T406, T501, T601, T701, T710, T720
Where: phone

### A22 — Above 1.3× nothing grows
Steps:
- Set Font size to the step nearest 1.3× (the agent reads `settings get system font_scale` over adb and names it; without adb, step down from the rightmost one step at a time, screenshotting the menu, until the text shrinks — the step before that is the last one the app follows).
- Screenshot the menu and Settings; set Font size back to the rightmost step and screenshot the same two screens.
Expected: The two pairs of screenshots are identical in text size.
Related: T601
Where: phone

### A23 — Both boards are playable, with Large cards too
Steps:
- Play a few moves in Klondike and in Spider by touch: select and place, drag, a stock tap, HINT, UNDO.
- Turn Large cards on in Settings, return to one board, and play a few more moves.
Expected: Every card and control is reachable and every move works as at the normal size; with Large cards the cards are bigger and still fit.
Related: T204, T218, T621
Where: phone

### A24 — Font size and Screen zoom back
Steps:
- Put Font size, Screen zoom and Large cards back as A01 recorded them.
Expected: The phone and the app look as they did before A20.
Related: T601
Where: phone

## Remove animations

### A30 — Remove animations on, Card animations still on
Steps:
- Settings → Accessibility → Vision enhancements (Visibility enhancements on older One UI) → Remove animations → on.
- In Honest Solitaire's Settings, check Card animations is on.
Expected: Both are on.
Related: T958
Where: phone

### A31 — The splash does not wait
Steps:
- Force stop the app and open it.
Expected: The splash reaches READY and the menu appears with no hold on READY and no fade.
Related: T001, T002
Where: phone

### A32 — Every card change is instant
Steps:
- Deal a Klondike game and a Spider game from their setup screens.
- Move a card by tap and by drag, uncover a face-down card, tap the stock, UNDO, and try a move that is refused.
- In Spider, complete a run if one is within reach (deal 924's lines do).
Expected: No deal flight, no slide, no flip, no settle after a drag, no run leaving for its slot: each change is there on the next frame. The refused card does not shake but you still feel the refusal's haptic tick.
Related: T957, T958, T204, T955
Where: phone

### A33 — A win shows its card at once
Steps:
- Win a game (deal 2982's lines by touch, then FINISH).
Expected: The FINISH sweep lands at once, there is no cascade, and the win card appears without rising or fading.
Related: T406, T412, T958
Where: phone

### A34 — Screens, the pause card, switches and the winnable search
Steps:
- Go menu → Settings → back; toggle a switch; pause a game and resume.
- New Klondike with the Deal choice on Winnable only (no deal number), and Deal.
Expected: Screens change with no cross-fade; the switch knob jumps; the pause card appears without rising. The winnable search's progress bar is a still bar, not a moving one, and the search still finishes.
Related: T140, T401, T601, T958
Where: phone

### A35 — Remove animations back
Steps:
- Put Remove animations back as A01 recorded it.
Expected: The phone is as before A30.
Related: T958
Where: phone

## Greyscale

The hint ring is dashed amber; the selection ring is solid teal (#102). In
greyscale the two must still be told apart by their shape. HINT's rings
clear on the next tap, so each board needs two screenshots: one with the
hint showing, one straight after selecting another card. The agent also
desaturates an ordinary colour screenshot of the same state for comparison;
the verdict is yours.

### A40 — Greyscale on
Steps:
- Settings → Accessibility → Vision enhancements → Colour adjustment (Colour filter on some versions) → on, Greyscale.
Expected: The whole screen is grey.
Related: T213
Where: phone

### A41 — Klondike: hint and selection on all three backs
Steps:
- In Settings pick Navy card back. New Klondike, Draw 1, deal number **3** (the test plan's D4): HINT (A♠ and its empty foundation are ringed), screenshot; select 6♥, screenshot.
- Same with deal number **8** (the test plan's D10): HINT rings the stock, screenshot.
- Repeat both with Teal, then Violet.
Expected: On every back the dashed hint rings — around a card, around the empty foundation slot, around the stock — are plainly different from the solid selection ring, and the face-down backs do not hide either.
Related: T213, T204, T602
Where: phone

### A42 — Spider: hint and selection on all three backs
Steps:
- Navy back. New Spider, One suit, deal number **48213** (D7): HINT (7♠ onto 8♠), screenshot; select another card, screenshot.
- Same with deal number **349** (D11): HINT rings the stock, screenshot.
- Repeat both with Teal, then Violet.
Expected: As A41: the dashed hint rings and the solid selection ring are told apart on every back.
Related: T213, T306, T602
Where: phone

### A43 — Greyscale back
Steps:
- Put Colour adjustment back as A01 recorded it; put Card back back as it was.
Expected: Every setting A01 recorded is back to its value.
Related: T601
Where: phone

## Filing

A failure is filed as in `qa/test-plan.md`'s "Filing a bug", with the title
prefixed by the part of the sweep: `[TalkBack]`, `[Font]`,
`[Remove animations]` or `[Greyscale]`. The issue names the A-check, the
TalkBack and One UI versions from A01 where they matter, and carries the
speech-caption or screen screenshot.
