# Honest Solitaire — test plan

What to check on a device, and how to record that it was checked. Every
screen, both games, every Settings row, every gesture, persistence across a
restart, and the sound, music, haptics and motion feedback each have numbered
checks below, in the order you reach them from the menu.

## How to use this plan

- **Runs.** A run is one pass through the plan on one device with the options
  of one row of the sampling table below (R1–R8). Set the row's Settings
  first, then its New Klondike or New Spider options, then run every
  `Core: yes` check for that game plus any check the row's Notes name. A
  check that names a deal from the Deals section is played with that deal's
  options, whatever the row says. Every
  option value is in at least one row; not every combination is (owner, round
  one of `/n8-plan M6`, 2026-09-24: every option once, not every combination).
- **Records.** Each run gets one record in `qa/runs/`, copied from
  `qa/runs/TEMPLATE.md` and named `YYYY-MM-DD-<device>-<who>[-n].md`, with
  `<device>` one of `s26ultra`, `emu-api24`, `emu-dev` and `<who>` one of
  `owner`, `agent`; `-2`, `-3` for a second or third run the same day. The
  owner reports phone results in chat; the agent transcribes them into the
  record and files the bugs.
- **Check fields.** Each check is `### T<nnn> — title` followed by `Steps:`
  (one action per line), `Expected:`, `Core:` (`yes` when the check exercises
  a rule, a score, a save or a navigation path), `Where:` (`phone`,
  `emulator` or `both`) and `Automated:` (the test that covers the same
  ground on the development machine, or `none`).
- **Numbering.** Hundreds by screen family: T0xx splash and menu, T1xx setup
  screens and the winnable search, T2xx Klondike board, T3xx Spider board,
  T4xx pause, win and banner, T5xx Statistics, T6xx Settings, T7xx How to
  play and About, T8xx persistence, T9xx gestures and feedback. IDs are never
  renumbered; a check that no longer applies keeps its number and reads
  `### T123 — title (retired)`.
- **Emulator runs are not hardware.** The reference device is the owner's
  Samsung Galaxy S26 Ultra. The oldest supported Android (7.0, API 24) and
  the smallest supported screen (320×568 dp) are covered only by the
  `solitaire-api24` emulator, and a result from an emulator is reported as an
  emulator result, never as a device result. Sound, music and haptics are
  judged on the phone.
- **History.** The owner's first play-through (2026-09-29, v0.2.0 from the
  internal track) ran from an interim checklist before this plan existed;
  its findings are #152, #153 and #154, and #115 records it. Its checks are
  not re-run under these IDs except where it did not reach them.

A "live game" below means a game with at least one move that is not won.
Cards are named rank then suit: `7♦`, `10♠`. "Force stop" means the phone's
Settings → Apps → Honest Solitaire → Force stop; "swipe away" means closing
the app from the recent-apps view.

## Sampling

Every row is a phone run on the S26 Ultra; an emulator run names the row it
reuses. `n/a` marks an option the row's game does not have. The Settings
columns are the Settings screen's rows, `on` or `off`.

| Run | Game | Draw | Scoring | Timer | Deal | Suits | Empty-column rule | Deal number | Card back | One-tap move | Auto-finish | Auto-flip cards | Unlimited undo | Winnable deals only | Left-handed layout | Large cards | Show timer | Show moves and score | Card animations | Sound effects | Background music | Haptics | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| R1 | Klondike | Draw 3 | Standard | Timed | Random deal | n/a | n/a | blank | Navy | on | on | on | on | off | off | off | on | on | on | on | off | on | first-run defaults; D2, D3 |
| R2 | Klondike | Draw 1 | Vegas | Untimed | Random deal | n/a | n/a | typed | Teal | off | off | on | off | off | on | off | off | on | on | off | on | on | type 48213 (D6); T953, T954 |
| R3 | Klondike | Draw 1 | None | Timed | Winnable only | n/a | n/a | blank | Violet | on | on | off | on | on | off | on | on | off | off | on | off | off | T140–T144 |
| R4 | Klondike | Draw 3 | Standard | Untimed | Winnable only | n/a | n/a | blank | Navy | on | on | on | on | on | off | off | on | on | on | on | off | on | T142 on the phone |
| R5 | Spider | n/a | n/a | Timed | n/a | One suit | Strict | blank | Navy | on | on | on | on | off | off | off | on | on | on | on | off | on | first Spider run |
| R6 | Spider | n/a | n/a | Untimed | n/a | Two suits | Relaxed | typed | Teal | on | on | on | on | off | on | on | on | on | on | off | off | off | type 48213 (D8) |
| R7 | Spider | n/a | n/a | Timed | n/a | Four suits | Relaxed | blank | Violet | off | on | off | off | off | off | off | on | on | off | on | on | on | |
| R8 | Spider | n/a | n/a | Untimed | n/a | Two suits | Strict | typed | Navy | on | off | on | on | off | off | off | off | off | on | on | off | on | type 48213 (D8) |

## Deals

Fixed deal numbers that reach a known state, so a check can start from it:
type the number into the Deal number field of the setup screen with the
options shown and tap Deal. `test/qa/deals_test.dart` replays every row with
the engine. Tops are each column's face-up card, left to right, with
Left-handed layout off. "First draw" is the waste after one stock tap, the
last card named on top. "First hint" is what HINT rings on the fresh deal.
The deal number is the seed alone, so the same number lays out the same
tableau in Draw 1 and Draw 3.

| Deal | Game | Options | Number | State |
|---|---|---|---|---|
| D1 | Klondike | Draw 1 | 48213 | tops: 2♣ 9♣ Q♦ 8♣ 7♣ 9♠ 7♦; first draw: 7♥; first hint: 7♦ onto 8♣ |
| D2 | Klondike | Draw 3 | 48213 | tops: 2♣ 9♣ Q♦ 8♣ 7♣ 9♠ 7♦; first draw: 7♥ 5♣ 4♥ |
| D3 | Klondike | Draw 3 | 71 | first hint: no moves left |
| D4 | Klondike | Draw 1 | 3 | tops: 2♥ 2♦ 6♥ A♠ 5♠ 6♣ Q♦; first hint: A♠ to foundation |
| D5 | Klondike | Draw 1 | 1 | solver: winnable |
| D6 | Klondike | Draw 1, Vegas | 48213 | score at deal: −$52 |
| D7 | Spider | One suit | 48213 | tops: 7♠ K♠ 3♠ 8♠ 9♠ 9♠ 6♠ 4♠ 10♠ 5♠; first hint: 7♠ onto 8♠ |
| D8 | Spider | Two suits | 48213 | tops: 7♠ K♥ 3♥ 8♥ 9♥ 9♠ 6♠ 4♠ 10♥ 5♠; first hint: 8♥ onto 9♥ |
| D9 | Spider | Four suits | 48213 | tops: 7♠ K♦ 3♦ 8♣ 9♣ 9♥ 6♠ 4♥ 10♦ 5♥; first hint: 8♣ onto 9♣ |

D5 is proven winnable by the same solver the app uses, with Auto-flip cards
on; playing it to a win still takes play.

## Splash

### T001 — The splash counts its loads, then opens the menu
Steps:
- Force stop the app.
- Launch it from its icon.
Expected: The splash shows the Honest mark, "Honest Solitaire", BY HONEST ARCADE and a bar that fills as the label moves through SHUFFLING, DEALING and READY; it fades to the menu. It shows for at least 600 ms, however fast the loads finish.
Core: yes
Where: both
Automated: test/ui/loading_screen_test.dart — progresses through the three labels as each load completes, never early, and stays at least 600 ms

### T002 — The splash follows the phone's Remove animations
Steps:
- Turn on the phone's Remove animations (Settings → Accessibility → Visibility enhancements on One UI).
- Force stop the app and launch it.
Expected: The splash reaches READY and the menu appears with no fade.
Core: no
Where: both
Automated: test/ui/loading_screen_test.dart — with the phone removing animations READY does not hold and the fade is instant

## Menu

### T010 — The menu shows every entry
Steps:
- Clear the app's data (Settings → Apps → Honest Solitaire → Storage → Clear data) and launch it.
Expected: The menu shows the wordmark, a New game button, a Klondike card ("Draw 1 or 3 · four foundations"), a Spider card ("1, 2 or 4 suits · ten columns"), Statistics, How to play, Settings, About the app, and an About Honest Arcade row reading "No ads, no tracking, open source."
Core: no
Where: both
Automated: test/ui/menu_navigation_test.dart — the menu shows the design and every button pushes its screen; back returns to the menu

### T011 — Every menu button opens its screen and back returns
Steps:
- Tap each of Klondike, Spider, Statistics, How to play, Settings, About the app and About Honest Arcade in turn.
- After each, press the screen's back arrow, then repeat with the phone's back gesture.
Expected: Each opens its screen (New Klondike game, New Spider game, Statistics, How to play, Settings, About the App, About Honest Arcade) with a cross-fade, and both kinds of back return to the menu.
Core: yes
Where: both
Automated: test/ui/menu_navigation_test.dart — the menu shows the design and every button pushes its screen; back returns to the menu

### T012 — New game with nothing saved opens New Klondike
Steps:
- With no game saved (fresh data, or after a win), tap New game.
Expected: The New Klondike game screen opens.
Core: yes
Where: both
Automated: test/ui/menu_navigation_test.dart — the resume button: none → "New game" opens New Klondike; a saved Klondike, then a saved Spider (last played wins)

### T013 — Continue offers the last game played
Steps:
- Make a move in a Klondike game, open the pause card and tap Main menu.
- Read the resume button, then tap it.
- Start a Spider game, make a move, return to the menu the same way.
Expected: The button reads "Continue Klondike" with "DRAW n · m MOVES" and returns to that board unpaused, as it was; after the Spider game it reads "Continue Spider" with "n SUITS · m MOVES".
Core: yes
Where: both
Automated: test/ui/menu_navigation_test.dart — the resume button: none → "New game" opens New Klondike; a saved Klondike, then a saved Spider (last played wins)

### T014 — Back on the menu leaves the app
Steps:
- On the menu, use the phone's back gesture.
Expected: The app closes to the home screen; relaunching shows the menu with the same Continue button.
Core: yes
Where: both
Automated: test/ui/menu_navigation_test.dart — back from Settings opened via the pause card returns to the board; back on the menu pops the app

## New Klondike

### T101 — First-run defaults and copy
Steps:
- With fresh data, tap Klondike on the menu.
Expected: "New Klondike game" with the kicker STANDARD 52-CARD DEAL; Cards per draw on Draw 3, Scoring on Standard, Timer on Timed, Deal on Random deal; an empty Deal number field reading "Random"; a Deal button.
Core: no
Where: both
Automated: test/ui/new_klondike_test.dart — first run: Draw 3, Standard, Timed, Random; the design copy is there

### T102 — Each choice changes the game dealt
Steps:
- Choose Draw 1, Vegas and Untimed.
- Tap Deal.
Expected: The board's title reads "Klondike · draw 1", the score readout starts at −$52, and there is no time readout.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — each choice changes the dealt game; Deal writes the last options and opens the board

### T103 — The last options come back; the Deal choice follows Settings
Steps:
- Deal a game with Draw 1, None, Untimed.
- Tap NEW on the board.
- Turn Winnable deals only on in Settings, then open New Klondike from the menu.
Expected: NEW opens New Klondike on Draw 1, None and Untimed. Deal shows Random deal until Winnable deals only is on in Settings; then it opens on Winnable only every visit, and choosing Random deal here is not remembered.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — defaults come from the last game; the Deal choice comes from Settings every visit

### T104 — A typed deal number forces Random deal and says why
Steps:
- Choose Winnable only.
- Type 48213 into Deal number.
- Clear the field with its ✕.
Expected: While the number is there, Random deal is selected, Winnable only is disabled and the Deal description reads "A chosen deal can't be promised winnable"; clearing it restores Winnable only.
Core: yes
Where: both
Automated: test/ui/deal_number_test.dart — a number forces Random and shows why; clearing restores Winnable only; the forced choice is never saved

### T105 — An out-of-range deal number disables Deal
Steps:
- Type 0, then replace it with 1000000.
- Try typing letters.
Expected: "Enter 1 to 999999" shows under the field and Deal is disabled for both; letters never appear in the field.
Core: no
Where: both
Automated: test/ui/deal_number_test.dart — 0 and 1000000 disable Deal and show the error live; letters are dropped

### T106 — A typed number deals that deal exactly
Steps:
- Choose Draw 1 and type 48213.
- Tap Deal.
- Tap the stock once.
Expected: The column tops read D1's: 2♣ 9♣ Q♦ 8♣ 7♣ 9♠ 7♦, and the waste shows 7♥. The pause card's line ends DEAL #48213.
Core: yes
Where: both
Automated: test/ui/deal_number_test.dart — blank deals randomly; 48213 deals that deal exactly, for Klondike

### T107 — Keep playing is in the teal accent and resumes the game
Steps:
- Make a move in a Klondike game.
- Tap NEW.
- Look at the button under Deal, then tap it.
Expected: "Keep playing the current game" is outlined, tinted and labelled in teal, clearly visible under the filled Deal button (#154); it returns to the same board, unpaused.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — Keep playing wears the screen's teal accent (#154)

### T108 — Dealing over a live Klondike records one loss
Steps:
- Note Klondike's GAMES PLAYED in Statistics.
- Make a move in a Klondike game, tap NEW, then Deal.
Expected: Klondike's GAMES PLAYED is one higher and CURRENT STREAK is 0; no Keep playing button shows until the new game has a move.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — dealing over an unfinished Klondike records one loss; a saved Klondike behind a live Spider too

## New Spider

### T120 — First-run defaults and copy
Steps:
- With fresh data, tap Spider on the menu.
Expected: "New Spider game" with the kicker TWO DECKS · 104 CARDS; Suits in play on Two suits ("The standard game."), with One suit and Four suits as the other rows; Timer on Timed; Empty-column rule on Strict; no winnable control.
Core: no
Where: both
Automated: test/ui/new_spider_test.dart — first run: Two suits, Timed, Strict; the design copy; no winnable control

### T121 — Each choice changes the game dealt
Steps:
- Choose One suit, Untimed and Relaxed.
- Tap Deal.
Expected: The title reads "Spider · 1 suit", the score shows 500, there is no time readout, and the tool row shows DEAL 5.
Core: yes
Where: both
Automated: test/ui/new_spider_test.dart — each choice changes the dealt game; Deal writes the last options and opens the board

### T122 — The last Spider options come back
Steps:
- Deal a Four suits, Untimed, Relaxed game.
- Open New Spider again from the menu.
Expected: Four suits, Untimed and Relaxed are selected.
Core: yes
Where: both
Automated: test/ui/new_spider_test.dart — defaults come from the last Spider game

### T123 — A typed number deals that Spider deal exactly
Steps:
- For each of One suit, Two suits and Four suits, type 48213 and tap Deal.
Expected: The column tops match D7, D8 and D9 in turn.
Core: yes
Where: both
Automated: test/ui/deal_number_test.dart — 48213 deals that deal exactly for Spider; a typed number equal to the current deal is allowed

### T124 — Keep playing is in the violet accent and resumes the game
Steps:
- Make a move in a Spider game.
- Tap NEW and look at the button under Deal, then tap it.
Expected: "Keep playing the current game" is outlined, tinted and labelled in violet (#154); it returns to the same board, unpaused.
Core: yes
Where: both
Automated: test/ui/new_spider_test.dart — Keep playing wears the screen's violet accent (#154)

### T125 — Dealing over a live Spider records one loss
Steps:
- Make a move in a Spider game, tap NEW, then Deal.
Expected: Spider's GAMES PLAYED in Statistics is one higher.
Core: yes
Where: both
Automated: test/ui/new_spider_test.dart — dealing over an unfinished Spider with a move records one loss

## Winnable search

### T140 — Winnable only searches with honest progress
Steps:
- On New Klondike choose Winnable only and tap Deal.
Expected: The screen reads FINDING A WINNABLE DEAL with a moving bar, a count "n deals tried" that grows, and a Cancel button; the board then opens on the deal found.
Core: yes
Where: both
Automated: test/ui/loading_screen_test.dart — shows the count, and Cancel cancels the dealer and returns

### T141 — Cancel returns and writes nothing
Steps:
- Start a winnable search and tap Cancel at once.
- Open New Klondike again.
Expected: Cancel returns to New Klondike; the last options and any saved Klondike are unchanged.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — Winnable only routes to the search; a cancelled search writes nothing

### T142 — The choice waits 5 s on the phone
Steps:
- On the S26 Ultra, choose Draw 3 and Winnable only on New Klondike.
- Tap Deal and start a stopwatch at the same moment.
- Repeat for five deals.
Expected: The count is shown while the search runs. "No winnable deal yet" with Keep searching and Deal a random game instead appears only after 5 s, never before; a deal found sooner opens the board without it. Write each time (to the board, or to the choice) in the run record's notes.
Core: yes
Where: phone
Automated: test/ui/loading_screen_test.dart — the soft limit offers both choices; Keep searching hides them and a Found opens the board on that deal

### T143 — Keep searching and Deal a random game instead
Steps:
- When the choice appears, tap Keep searching.
- When it appears again, tap Deal a random game instead.
Expected: Keep searching hides the choice and the count carries on; the choice returns after 10 s more. Deal a random game instead opens the board on a random deal with the same options.
Core: yes
Where: both
Automated: test/ui/loading_screen_test.dart — Deal a random game instead cancels the search and deals a non-winnable game with the same options

### T144 — Back during the search cancels it
Steps:
- Start a winnable search and use the phone's back gesture.
Expected: The search stops and New Klondike shows again.
Core: yes
Where: both
Automated: test/ui/loading_screen_test.dart — NotFound shows the fallback with random-instead and Back; system back cancels

## Klondike board

### T201 — The board at the deal
Steps:
- Deal a Draw 3, Standard, Timed Klondike game.
Expected: Seven columns, the stock, four empty foundations each showing its suit, a pause pill titled "Klondike · draw 3", and readouts 0:00, 0 MOV and 0 PTS. The clock stays at 0:00 until the first move, then counts each second.
Core: yes
Where: both
Automated: test/ui/top_bar_clock_test.dart — standard shows time, MOV and PTS; the title names the game

### T202 — The same number deals the same cards on this device
Steps:
- Deal D1, then D2, and compare them with the Deals table.
Expected: Both show D1's tops; D1's first stock tap shows 7♥; D2's shows 7♥ 5♣ 4♥ with 4♥ on top.
Core: yes
Where: both
Automated: test/qa/deals_test.dart — D1: Klondike Draw 1 #48213 reaches the states the plan names

### T203 — The stock turns one or three and recycles
Steps:
- In a Draw 3 game, tap the stock until it is empty.
- Tap the empty stock.
Expected: Each tap turns three cards (fewer at the end) onto the waste; the empty stock shows ↻ and one more tap turns the waste back into the stock. In a Standard game each recycle costs 2 points, never below 0.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — tapping the stock draws three; an empty stock recycles

### T204 — Select, then place; an illegal place shakes
Steps:
- With One-tap move off, tap a face-up card or run.
- Tap a legal column.
- Select another card and tap an illegal column.
Expected: The selection rings; the legal tap moves the run and clears the ring; the illegal tap shakes, changes nothing and clears the selection.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — select, then an illegal target: a shake, no change, selection cleared

### T205 — One-tap move sends a card to its best place
Steps:
- With One-tap move on, deal D1 and tap 7♦.
Expected: 7♦ moves onto 8♣ at once. A card with nowhere to go is selected instead.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — one-tap moves a card to its best destination, or selects it when there is none

### T206 — Taking a card back off a foundation
Steps:
- With a card on a foundation, tap it, then tap a column that takes it.
Expected: The foundation card is selected, never one-tapped away; placing it on the column costs 15 points in Standard and $5 in Vegas.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — a foundation card is selected, never one-tapped away

### T207 — Standard scoring
Steps:
- In a Standard game, move a card to a foundation, move a waste card to a column, and uncover a face-down card.
Expected: The score rises by 10, 5 and 5; it never shows below 0.
Core: yes
Where: both
Automated: test/engine/klondike_scoring_test.dart — +10 to a foundation from the tableau and from the waste

### T208 — The timed Standard penalty
Steps:
- In a Timed Standard game with a score above 0, make a move and wait 30 s.
Expected: The score falls by 2 every 10 s of play, never below 0; it stops falling while paused.
Core: yes
Where: both
Automated: test/engine/klondike_scoring_test.dart — timed standard: each full 10 s costs 2, never below 0

### T209 — Vegas scoring
Steps:
- Deal D6.
- Move a card to a foundation.
Expected: The score starts at −$52 and rises by $5 per foundation card; it can stay below zero and shows a minus sign.
Core: yes
Where: both
Automated: test/ui/top_bar_clock_test.dart — Vegas shows dollars with the minus sign; none hides the score

### T210 — No score and untimed
Steps:
- Deal a None, Untimed game.
Expected: The top bar shows only the move count; no score and no time.
Core: yes
Where: both
Automated: test/ui/top_bar_clock_test.dart — each hide setting removes its readout; untimed hides the time

### T211 — Auto-flip off leaves an uncovered card face down
Steps:
- With Auto-flip cards off in Settings, deal a game and uncover a face-down card.
- Tap it.
Expected: The card stays face down until tapped; the tap turns it and scores 5 in Standard.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — taps on face-down cards or broken runs do nothing; auto-flip off flips a top

### T212 — UNDO, unlimited and limited
Steps:
- Deal a game: UNDO is disabled.
- Make three moves and tap UNDO three times.
- Turn Unlimited undo off, make two moves and tap UNDO twice; draw from the stock and tap UNDO.
Expected: Unlimited undo steps back all three moves, score included. With it off only the last move undoes, UNDO then disables until the next move, and a draw never undoes.
Core: yes
Where: both
Automated: test/ui/tool_row_test.dart — limited undo disables after one undo until the next move

### T213 — HINT rings the move
Steps:
- Deal D1 and tap HINT.
- Tap anywhere.
Expected: HINT rings 7♦ and 8♣ in amber (dashed); the next tap clears the rings. On D4 it rings A♠ and its foundation.
Core: yes
Where: both
Automated: test/ui/tool_row_test.dart — HINT rings the source run and its destination, and clears on the next tap

### T214 — FINISH sweeps a solved board
Steps:
- With Auto-finish off, play a game until every tableau card is face up.
- Tap FINISH.
Expected: FINISH is disabled while any tableau card is face down; once the board can finish it enables, sweeps every card (the stock's included) to the foundations, and the win card follows.
Core: yes
Where: both
Automated: test/ui/tool_row_test.dart — FINISH is disabled until the board can finish, then sweeps it

### T215 — Auto-finish sweeps a solved board by itself
Steps:
- With Auto-finish on, play until every tableau card is face up and the stock and waste are empty.
Expected: The move that leaves the board in that state starts the sweep at once, card by card, to the win card.
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — on: a move that solves the board sweeps it step by step to the win card

### T216 — RESTART and NEW
Steps:
- Make a move and tap RESTART.
- Tap NEW, then back.
Expected: RESTART deals the same deal again at once (the move counts as a loss in Statistics). NEW opens New Klondike; back returns to the board as it was.
Core: yes
Where: both
Automated: test/ui/pause_win_complete_test.dart — NEW, New deal on the pause card and New deal on the win card open the right setup screen; back returns to the board as it was

### T217 — Left-handed layout mirrors the top row and the tool row
Steps:
- Turn Left-handed layout on and return to a Klondike board.
Expected: The stock and waste sit at the right, the foundations at the left, and the tool row reads NEW first; the columns are unchanged.
Core: no
Where: both
Automated: test/ui/board_layout_test.dart — Klondike mirrors the top row exactly and leaves the tableau alone

### T218 — Large cards and card backs apply at once
Steps:
- Mid-game, turn Large cards on and pick another card back in Settings.
- Return to the board.
Expected: The cards are larger with bigger ranks and suits, the face-down cards wear the new back, and the game is exactly where it was.
Core: no
Where: both
Automated: test/ui/app_layout_test.dart — display settings apply at once without restarting the game

### T219 — The smallest screen fits the board
Steps:
- On `solitaire-api24`, deal a Draw 3 game and play until a column holds a long run.
Expected: Nothing is cut off or overlaps the tool row; the top bar, all seven columns and the tool row are fully visible.
Core: no
Where: emulator
Automated: test/ui/app_layout_test.dart — at 320×568 nothing leaves the safe area

## Spider board

### T301 — The board at the deal
Steps:
- Deal a Two suits, Timed Spider game.
Expected: Ten columns, the stock's five slivers at the right, empty completed-run slots at the left, a pause pill titled "Spider · 2 suits", and readouts 0:00, 0 MOV and 500 PTS; the tool row shows UNDO, HINT, DEAL 5, RESTART, NEW.
Core: yes
Where: both
Automated: test/ui/top_bar_clock_test.dart — Spider shows PTS 500 and its suit count

### T302 — The same number deals the same Spider cards
Steps:
- Deal D7, D8 and D9 and compare with the Deals table.
Expected: Each shows its tops; HINT rings the pair the table names.
Core: yes
Where: both
Automated: test/qa/deals_test.dart — D8: Spider Two suits #48213 reaches the states the plan names

### T303 — A deal drops one card on every column
Steps:
- Tap the stock, then tap DEAL.
Expected: Each deals one face-up card onto every column; the slivers and the DEAL count drop by one each time.
Core: yes
Where: both
Automated: test/ui/tool_row_test.dart — DEAL shows the rows left, deals, and is refused like the stock

### T304 — Strict refuses a deal with an empty column
Steps:
- In a Strict game, empty a column.
- Tap the stock.
Expected: The stock shakes and nothing changes.
Core: yes
Where: both
Automated: test/ui/spider_board_test.dart — a strict deal with an empty column shakes the stock and changes nothing

### T305 — Relaxed deals with an empty column
Steps:
- In a Relaxed game, empty a column and tap the stock.
Expected: The row deals, the empty column included.
Core: yes
Where: both
Automated: test/engine/spider_test.dart — strict refuses a deal with an empty column; relaxed allows it

### T306 — Only a same-suit run moves as a group
Steps:
- In a Two or Four suits game, find a column whose face-up cards mix suits.
- With One-tap move off, tap its lowest face-up card; then turn One-tap move on and tap it again.
Expected: Only the same-suit run at the top of that column is selected; with One-tap move on that run moves to its best column.
Core: yes
Where: both
Automated: test/ui/spider_board_test.dart — a mixed-suit tap selects only the same-suit run above it, and one-tap moves that run

### T307 — A completed run leaves the board
Steps:
- Build K down to A of one suit in a column.
Expected: The run leaves the column into the first empty completed slot in the same moment, the score rises by 100 (99 with its move), and a card it uncovers turns up.
Core: yes
Where: both
Automated: test/ui/spider_board_test.dart — a completed run leaves the column and fills the first slot in the same frame

### T308 — Spider scoring
Steps:
- Make five moves in a fresh game.
Expected: The score is 495: 500 at the deal, minus 1 per move, never below 0.
Core: yes
Where: both
Automated: test/engine/spider_scoring_test.dart — the deal is 500 and every move costs one

### T309 — A second stock tap right after a deal is ignored
Steps:
- Tap the stock twice quickly.
Expected: One row is dealt, not two.
Core: no
Where: both
Automated: test/ui/spider_board_test.dart — a second stock tap within 300 ms of a deal is ignored

### T310 — Left-handed Spider
Steps:
- With Left-handed layout on, open a Spider board.
Expected: The stock is at the left and the completed slots at the right; the tool row is reversed.
Core: no
Where: both
Automated: test/ui/board_layout_test.dart — Spider puts the stock at the left and the completed slots at the right

## Pause, win and banner

### T401 — The pause card
Steps:
- On a Klondike Vegas board, tap the pause pill.
Expected: The pause card covers the board: "Paused" with the line "KLONDIKE · DRAW n · VEGAS · DEAL #n" (NO SCORE for None; "SPIDER · n SUITS · DEAL #n" in Spider) and Resume, Restart this deal, New deal, Rules, Settings and Main menu; the clock stops.
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — shows the mode line with the deal number and its buttons, and no more

### T402 — Back and leaving the app pause the game
Steps:
- On a board, use the phone's back gesture; then use it again.
- Go to the home screen and return to the app.
Expected: Back pauses, back again resumes; returning from the home screen shows the pause card.
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — system back pauses, then resumes; returning from the background pauses

### T403 — Rules and Settings from the pause card
Steps:
- Pause a Spider game and tap Rules; go back.
- Tap Settings; go back.
Expected: Rules opens How to play on the Spider tab; each back returns to the board, still paused.
Core: yes
Where: both
Automated: test/ui/pause_win_complete_test.dart — the pause card has Rules, Settings and Main menu, no Switch; Rules and Settings return to the board paused

### T404 — Restart this deal and New deal
Steps:
- Pause and tap Restart this deal.
- Pause and tap New deal, then back.
Expected: Restart this deal shows the same deal at its start at once. New deal opens the game's setup screen; back returns to the board.
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — Restart this deal restores the deal at once; New deal deals afresh

### T405 — Main menu keeps the game
Steps:
- Pause a live game and tap Main menu.
- Tap Continue.
Expected: No loss is recorded in Statistics; Continue brings the game back unpaused.
Core: yes
Where: both
Automated: test/ui/pause_win_complete_test.dart — Main menu keeps the game resumable, records no loss, and Continue brings it back unpaused

### T406 — The Klondike win card
Steps:
- Win a Timed Standard Klondike game (D5 is winnable).
Expected: The cards cascade off the screen, then GAME COMPLETE, "Foundations complete", with TIME, MOVES, SCORE, STREAK and TIME BONUS, and New deal, See statistics and Main menu.
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — a timed standard win shows TIME, MOVES, SCORE and TIME BONUS

### T407 — A win through auto-finish is recorded and not offered again
Steps:
- Note Klondike's GAMES PLAYED and WIN RATE in Statistics.
- With Auto-finish on, win a Klondike game by letting the sweep finish it.
- Tap Main menu on the win card.
Expected: Statistics shows one more game played and one more won; the menu offers New game or the other game, never "Continue Klondike" (#152).
Core: yes
Where: both
Automated: test/data/stats_test.dart — a win reached through auto-finish is recorded once (#152)

### T408 — A win through FINISH is recorded and not offered again
Steps:
- With Auto-finish off, solve a Klondike board and tap FINISH.
- Tap Main menu on the win card.
Expected: As T407: the win counts once in Statistics and there is no "Continue Klondike" (#152).
Core: yes
Where: both
Automated: test/data/game_saves_test.dart — a win reached through FINISH clears the slot and offers no resume (#152)

### T409 — The win card's buttons
Steps:
- On a win card tap See statistics, then back.
- Tap New deal; go back; tap Main menu.
Expected: See statistics opens Statistics on this game's tab with the new win counted; back returns to the win card. New deal opens the setup screen. Main menu offers no Continue for the won game.
Core: yes
Where: both
Automated: test/ui/pause_win_complete_test.dart — the win card shows the streak after the win is recorded; See statistics opens this tab and back returns to the win card; Main menu offers no Continue

### T410 — Vegas, None and Untimed win cards
Steps:
- Win a Vegas game, a None game and an Untimed game.
Expected: Vegas shows DOLLARS in place of SCORE; None shows no score; Untimed shows no TIME and no TIME BONUS.
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — Vegas shows DOLLARS; none hides the score; untimed shows no time or bonus

### T411 — The Spider win card
Steps:
- Win a Spider game (One suit is the gentlest).
Expected: The eight Kings cascade, then GAME COMPLETE, "All eight runs home".
Core: yes
Where: both
Automated: test/ui/win_cascade_test.dart — a won Spider drops its eight Kings at tableau size, then the win card

### T412 — A tap skips the cascade
Steps:
- Win a game and tap the board during the cascade.
Expected: The win card shows at once.
Core: no
Where: both
Automated: test/ui/win_cascade_test.dart — a tap on the board shows the win card on the next frame

### T413 — No moves left
Steps:
- Deal D3 and tap HINT.
- Tap New deal on the banner.
Expected: "No moves left" replaces the readouts in the top bar, with Undo (disabled at the deal) and New deal; New deal deals a different Draw 3 game.
Core: yes
Where: both
Automated: test/ui/tool_row_test.dart — no moves left shows the banner in place of the readouts, with working buttons

### T414 — The cards fit the smallest screen
Steps:
- On `solitaire-api24`, open the pause card, then win a game.
Expected: Both cards fit with nothing cut off.
Core: no
Where: emulator
Automated: test/ui/pause_win_complete_test.dart — on a 320×568 phone both cards fit without overflow

## Statistics

### T501 — Empty statistics
Steps:
- With fresh data, open Statistics.
Expected: Klondike and Spider tabs; the six cards (GAMES PLAYED, WIN RATE, BEST TIME, FEWEST MOVES, CURRENT STREAK, HIGH SCORE) show "—"; Reset statistics is disabled.
Core: yes
Where: both
Automated: test/ui/stats_screen_test.dart — empty stats show "—" everywhere and Reset is disabled; a negative Vegas total shows minus dollars

### T502 — Records after play
Steps:
- Win one Klondike game and lose one (a move, then a new deal).
- Open Statistics on the Klondike tab, then the Spider tab.
Expected: GAMES PLAYED 2, WIN RATE 50%, BEST TIME and FEWEST MOVES from the win (BEST TIME only for a timed win), CURRENT STREAK 0, HIGH SCORE from a Standard win with Total play under it; the Spider tab shows its own records.
Core: yes
Where: both
Automated: test/data/stats_test.dart — a win counts played, won, streak, time, best time, fewest moves and high score

### T503 — The breakdowns
Steps:
- Play Klondike in both draw modes and in Vegas; play Spider at each suit count.
Expected: BY DRAW MODE shows Draw one and Draw three as "won / played · %" and Vegas scoring as a lifetime dollar total; BY SUIT COUNT shows One suit, Two suits and Four suits. A Vegas game never sets HIGH SCORE.
Core: yes
Where: both
Automated: test/data/stats_test.dart — Vegas wins and losses add lifetime dollars and never set a high score; none scores nothing

### T504 — A game with no move counts nothing
Steps:
- Deal a game, make no move, and deal another.
Expected: GAMES PLAYED does not change.
Core: yes
Where: both
Automated: test/data/stats_test.dart — a game with no move then a new deal records nothing; one move then a new deal records a loss

### T505 — Reset statistics
Steps:
- Tap Reset statistics, then Cancel.
- Tap it again, then Reset.
Expected: The confirmation reads "Reset statistics?" and says every recorded game, streak, best time and score for both games is cleared and that nothing was uploaded; Cancel leaves everything; Reset empties both tabs.
Core: yes
Where: both
Automated: test/ui/stats_screen_test.dart — Cancel leaves the document; Reset clears both games and the confirm copy is the corrected one

### T506 — Statistics opens on the current game
Steps:
- With a Spider game live, open Statistics from the menu.
Expected: It opens on the Spider tab.
Core: no
Where: both
Automated: test/ui/stats_screen_test.dart — opened with a Spider game it starts on Spider

## Settings

### T601 — The Settings screen
Steps:
- Open Settings from the menu.
Expected: A Card back panel (Navy, Teal, Violet swatches; "Every back carries the Honest Arcade mark."), then PLAY (One-tap move, Auto-finish, Auto-flip cards, Unlimited undo, Winnable deals only), DISPLAY (Left-handed layout, Large cards, Show timer, Show moves and score, Card animations) and SOUND (Sound effects, Background music, Haptics), each with its description; the STORED ON DEVICE ONLY note; and the version line `v<version> · BUILD <code>`. Copy the version line into the run record's Build field.
Core: no
Where: both
Automated: test/ui/settings_screen_test.dart — every row renders with the design default; the note, the version and the swatches are there

### T602 — Card back
Steps:
- Tap each swatch in turn and look at a board's stock.
Expected: The selected swatch is marked and the face-down cards wear that back at once.
Core: no
Where: both
Automated: test/ui/app_layout_test.dart — display settings apply at once without restarting the game

### T603 — Back from Settings returns where it was opened
Steps:
- Open Settings from the menu, go back; open it from the pause card, go back.
Expected: Back returns to the menu, then to the paused board.
Core: yes
Where: both
Automated: test/ui/menu_navigation_test.dart — back from Settings opened via the pause card returns to the board; back on the menu pops the app

### T610 — One-tap move
Steps:
- Turn One-tap move off, then on, tapping a card on the board each time.
Expected: Off: a tap selects. On: a tap moves the card to its best place (T205).
Core: yes
Where: both
Automated: test/ui/settings_screen_test.dart — toggling updates the notifier and the stored document; the board reflects it

### T611 — Auto-finish
Steps:
- Turn Auto-finish off, then on, solving a board each time.
Expected: Off: nothing happens until FINISH (T214). On: the sweep starts by itself (T215).
Core: yes
Where: both
Automated: test/ui/pause_win_test.dart — off: nothing happens until FINISH

### T612 — Auto-flip cards, and the next-deal note
Steps:
- With a live game, turn Auto-flip cards off.
- Deal a new game and uncover a face-down card.
Expected: "Applies to your next deal" shows under Auto-flip cards while the game is live; the current game keeps flipping, the next one leaves uncovered cards face down (T211).
Core: yes
Where: both
Automated: test/ui/settings_screen_test.dart — "Applies to your next deal" shows under Auto-flip and Winnable only while a game is live

### T613 — Unlimited undo
Steps:
- Turn Unlimited undo off and on, as in T212.
Expected: Off: only your last move, and never a draw. On: any number of moves.
Core: yes
Where: both
Automated: test/engine/undo_test.dart — never undoes a draw, a recycle or a Spider row deal

### T614 — Winnable deals only
Steps:
- With a live Klondike game, turn Winnable deals only on.
- Open New Klondike.
Expected: "Applies to your next deal" shows under it while a Klondike game is live (not for a live Spider game); New Klondike opens on Winnable only.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — Settings default applies unless overridden here; the override is not remembered

### T620 — Left-handed layout
Steps:
- Turn Left-handed layout on and off.
Expected: The boards mirror as in T217 and T310, and return when it is off.
Core: no
Where: both
Automated: test/ui/tool_row_test.dart — left-handed reverses the order; glyphs and labels are present

### T621 — Large cards
Steps:
- Turn Large cards on and off with a board open behind Settings.
Expected: The cards grow and shrink back (T218).
Core: no
Where: both
Automated: test/ui/board_layout_test.dart — Klondike: 52×78 with fractional gaps filling the frame exactly

### T622 — Show timer
Steps:
- Turn Show timer off and return to a timed game.
Expected: The time readout is gone; the clock still counts (it is back when the setting is on).
Core: no
Where: both
Automated: test/ui/top_bar_clock_test.dart — each hide setting removes its readout; untimed hides the time

### T623 — Show moves and score
Steps:
- Turn Show moves and score off and return to a game.
Expected: MOV and the score readout are gone; they return when it is on.
Core: no
Where: both
Automated: test/ui/top_bar_clock_test.dart — each hide setting removes its readout; untimed hides the time

### T624 — Card animations
Steps:
- Turn Card animations off, deal a game, move a card, win a game.
Expected: No deal flight, slides, flips or cascade; screens still cross-fade, faster. On again, they all return (T957).
Core: no
Where: both
Automated: test/ui/deal_animation_test.dart — with Card animations off there is no deal

### T630 — Sound effects
Steps:
- Turn Sound effects off, then on.
Expected: Off: the game is silent. Turning it on plays one snap (T950, T951).
Core: no
Where: phone
Automated: test/feedback/sound_player_test.dart — turning Sound effects on plays one snap; the restore at launch plays none

### T631 — Background music
Steps:
- Turn Background music on and open a board.
Expected: A quiet loop plays while you play (T952).
Core: no
Where: phone
Automated: test/feedback/sound_player_test.dart — starts only with a board showing, unpaused, foreground and the setting; pauses on each; stops only on a new game

### T632 — Haptics
Steps:
- Turn Haptics off, then on.
Expected: Turning it on gives exactly one tick; off, nothing ticks (T955).
Core: no
Where: phone
Automated: test/feedback/haptics_test.dart — restored on at launch: no tick; turned on by the player: exactly one light impact

## How to play

### T701 — Both tabs and the gestures
Steps:
- Open How to play from the menu and switch between the tabs.
Expected: Klondike shows THE GOAL, THE TABLEAU, THE STOCK, SCORING and RECORDS; Spider shows THE GOAL, MOVING CARDS, THE DEALS, DIFFICULTY, SCORING and RECORDS; both show GESTURES: TAP, DOUBLE TAP, DRAG, TAP STOCK and LONG PRESS. The tabs switch at once.
Core: no
Where: both
Automated: test/ui/how_to_play_test.dart — both tabs render all their cards and the five gestures; the tabs switch instantly

### T702 — The scoring cards state the rules the game plays
Steps:
- Read both SCORING cards.
Expected: Klondike: ten per foundation card, five for waste to tableau and for a turned card, minus fifteen for a card taken back, minus two per pass, Vegas minus fifty-two at the deal. Spider: five hundred at the deal, minus one per move, plus one hundred per run. These match T207, T209 and T308.
Core: yes
Where: both
Automated: test/ui/how_to_play_test.dart — the Spider scoring card states 500, and the Klondike one the -15, penalty and Vegas deal

## About the App

### T710 — The About the App screen
Steps:
- Open About the app from the menu.
Expected: The Honest Solitaire tile with the same version as Settings, the feature list (Klondike, both draws; Spider, three difficulties; Unlimited undo and hints; Auto-finish and one-tap moves; Honest statistics; Three card backs), THE HONEST PROMISES with an Honest Arcade Promises button, and MADE BY HONEST ARCADE · SOURCE ON GITHUB.
Core: no
Where: both
Automated: test/ui/about_screens_test.dart — About the App renders every section

### T711 — About the App's links
Steps:
- Tap HONEST ARCADE, return; tap SOURCE ON GITHUB, return.
Expected: The phone's browser opens honestarcade.app, then github.com/honestarcade/HonestSolitaire; back returns to the app.
Core: yes
Where: both
Automated: test/ui/about_screens_test.dart — each link calls openUrl with its URL through the channel

### T712 — Honest Arcade Promises opens About Honest Arcade
Steps:
- Tap Honest Arcade Promises, then back.
Expected: About Honest Arcade opens; back returns to About the App.
Core: yes
Where: both
Automated: test/ui/about_screens_test.dart — About the App renders every section

## About Honest Arcade

### T720 — The About Honest Arcade screen
Steps:
- Open About Honest Arcade from the menu's row.
Expected: SUPPORT HONEST ARCADE, OUR PROMISES, the NO ADS, NO TRACKING and OPEN SOURCE pills, and the HONESTARCADE.APP and SOURCE ON GITHUB links.
Core: no
Where: both
Automated: test/ui/about_screens_test.dart — About Honest Arcade renders every section, with the backup qualifier

### T721 — Support and site links
Steps:
- Tap SUPPORT HONEST ARCADE, return; tap HONESTARCADE.APP, return.
Expected: The browser opens honestarcade.app/contribute, then honestarcade.app.
Core: yes
Where: both
Automated: test/ui/about_screens_test.dart — each link calls openUrl with its URL through the channel

### T722 — The source link opens this game's repository
Steps:
- Tap SOURCE ON GITHUB.
Expected: The browser opens github.com/honestarcade/HonestSolitaire, not the Honest Arcade organisation page (#153).
Core: yes
Where: both
Automated: test/ui/about_screens_test.dart — each link calls openUrl with its URL through the channel

### T723 — No browser
Steps:
- On `solitaire-dev`, disable every browser (`adb shell pm disable-user <package>`), then tap a link.
Expected: A message reads "COULDN'T OPEN <LINK> — NO BROWSER FOUND"; nothing crashes. Re-enable the browsers afterwards.
Core: no
Where: emulator
Automated: test/ui/about_screens_test.dart — a false result or a channel error shows the message; nothing crashes

## Gestures

### T901 — Tap
Steps:
- Tap a card, then a column, foundation or free space; tap the felt with a card selected.
Expected: The first tap selects, the second places; a tap on the felt or the selected card clears the selection.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — tapping the felt or the selected card clears the selection

### T902 — Double tap
Steps:
- Deal D4 and double-tap A♠ (One-tap move off).
- In Spider, double-tap the top of a same-suit run.
Expected: A♠ goes straight to its foundation; the Spider run goes to its best column.
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — a double tap sends an ace to its foundation without delaying the first tap

### T903 — Drag
Steps:
- Drag a card or run to a legal column and drop it.
- Drag one to an illegal column, to the felt and back onto its own column.
- In Draw 3, drag the waste.
Expected: A legal drop applies one move; every other drop springs back to where it came from. Only the waste's top card drags.
Core: yes
Where: both
Automated: test/ui/drag_peek_test.dart — an illegal drop, a felt drop and a drop on its own column spring back

### T904 — Tap stock
Steps:
- Tap the stock in Klondike until it recycles; tap the stock in Spider.
Expected: Klondike turns cards and recycles the waste (T203); Spider deals a row (T303).
Core: yes
Where: both
Automated: test/ui/klondike_board_test.dart — tapping the stock draws three; an empty stock recycles

### T905 — Long press
Steps:
- Long-press a crowded column; release.
- Long-press again and move your finger.
- Long-press a face-down card.
Expected: The column's face-up cards spread to full spacing while held and close on release; moving turns the press into a drag of the pressed card; a face-down card peeks but never drags.
Core: yes
Where: both
Automated: test/ui/drag_peek_test.dart — a long press fans the face-up cards to full spacing and restores them on release

## Persistence

### T801 — A Klondike game survives a swipe-away
Steps:
- Make several moves in a Klondike game; note the moves, score and time.
- Swipe the app away and relaunch it.
- Tap Continue Klondike, then UNDO.
Expected: The board, moves, score and time are as they were; UNDO steps back the last move.
Core: yes
Where: both
Automated: test/data/game_saves_test.dart — a saved game of each type loads back exactly, undo included, with lastPlayed

### T802 — A Spider game survives a force stop
Steps:
- Make several moves in a Spider game.
- Force stop the app and relaunch it.
- Tap Continue Spider.
Expected: The board, rows left, moves, score and time are as they were.
Core: yes
Where: both
Automated: test/ui/menu_navigation_test.dart — Continue on a cold start reconstructs the saved game from disk, not the launch deal (#143)

### T803 — Both saved games are kept
Steps:
- Leave a live Klondike game, then a live Spider game, each through Main menu.
- Force stop and relaunch.
- Tap Continue, then open New Klondike.
Expected: Continue offers Spider (the last played); New Klondike offers Keep playing, which resumes the Klondike game as it was.
Core: yes
Where: both
Automated: test/data/game_saves_test.dart — a saved game of each type loads back exactly, undo included, with lastPlayed

### T804 — Settings survive
Steps:
- Change the card back and at least three Settings rows.
- Swipe the app away and relaunch; then force stop and relaunch.
Expected: Every change is still there both times.
Core: yes
Where: both
Automated: test/ui/settings_screen_test.dart — a relaunch over the same store restores every value

### T805 — Statistics survive, and a restart records nothing
Steps:
- Note both tabs of Statistics with a live game saved.
- Force stop and relaunch; open Statistics.
Expected: Both tabs are unchanged; relaunching over a saved game records no loss.
Core: yes
Where: both
Automated: test/data/stats_test.dart — an app restart with a saved game records nothing; finishing it later records once

### T806 — The last options survive
Steps:
- Deal Klondike with Draw 1, Vegas, Untimed and Spider with Four suits, Relaxed.
- Force stop and relaunch; open New Klondike and New Spider.
Expected: Both screens open on those options.
Core: yes
Where: both
Automated: test/ui/new_klondike_test.dart — defaults come from the last game; the Deal choice comes from Settings every visit

### T807 — A won game is not offered after a relaunch
Steps:
- Win a game and force stop the app on the win card.
- Relaunch.
Expected: The menu does not offer Continue for the won game, and the win is counted once.
Core: yes
Where: both
Automated: test/data/stats_test.dart — a crash between a win and its record: relaunch reconciles it once, from a fresh recorder and listener (#141)

### T810 — A damaged file raises the banner
Steps:
- On `solitaire-dev` with a debug build, make a move and force stop the app.
- Run `adb shell run-as com.honestarcade.solitaire sh -c 'echo broken > files/data/stats.json'`.
- Launch the app; return to the menu from another screen; tap ✕ on the banner.
Expected: The menu shows "Couldn't load your statistics." with a ✕; it stays across returns to the menu until ✕ dismisses it; Statistics starts empty and the saved game is intact.
Core: yes
Where: emulator
Automated: test/ui/menu_navigation_test.dart — the corruption banner combines two notices and stays across a return to the menu until ✕

## Feedback

### T950 — Sound effects
Steps:
- With Sound effects on and the media volume up, deal a game, draw, make a move that uncovers a card, and bring a foundation to its King (or complete a Spider run).
Expected: A deal sound on the deal (and on each Spider row), a snap on the draw and ordinary moves, a flip when a card turns up, a chime when a foundation reaches its King, a run completes or the game is won; refusals are silent.
Core: no
Where: phone
Automated: test/feedback/sound_player_test.dart — a draw snaps, a revealing move flips, a King chimes, a refusal and undo are as told

### T951 — Sound effects off is silent
Steps:
- Turn Sound effects off and play a few moves.
Expected: Nothing plays.
Core: no
Where: phone
Automated: test/feedback/sound_player_test.dart — turning Sound effects on plays one snap; the restore at launch plays none

### T952 — Background music follows the board
Steps:
- Turn Background music on and open a board.
- Pause; resume; open Settings from the pause card; return; go to the home screen; return.
Expected: The loop plays only while an unpaused board is showing with the app in front; it pauses for each of the others and plays again on return.
Core: no
Where: phone
Automated: test/feedback/sound_player_test.dart — starts only with a board showing, unpaused, foreground and the setting; pauses on each; stops only on a new game

### T953 — Music never plays over another app's audio
Steps:
- Start a podcast or music in another app.
- Open a board with Background music on.
Expected: The game's music does not start and the other audio keeps playing, unducked.
Core: no
Where: phone
Automated: test/feedback/sound_player_test.dart — never starts while another app plays audio, and retries at the next change

### T954 — The volume keys control the game's sound
Steps:
- On a board, press the volume keys.
Expected: The media volume changes, not the ringer.
Core: no
Where: phone
Automated: none

### T955 — Haptics
Steps:
- With Haptics on, make an illegal move, an ordinary move, complete a Spider run or a Klondike foundation, and long-press a column.
Expected: One short tick for the illegal move, the completed run or foundation, and the start of the peek; none for the ordinary move.
Core: no
Where: phone
Automated: test/feedback/haptics_test.dart — refusals, runs, foundations and peeks tick; the rest do not

### T956 — Haptics off
Steps:
- Turn Haptics off and repeat T955.
Expected: No ticks.
Core: no
Where: phone
Automated: test/feedback/haptics_test.dart — restored on at launch: no tick; turned on by the player: exactly one light impact

### T957 — Card animations
Steps:
- With Card animations on, deal a game, move a card, uncover one, and win a game.
Expected: The deal flies from the stock to the columns, moved cards slide, uncovered cards flip, and a win cascades; screens cross-fade and the pause card rises into place.
Core: no
Where: both
Automated: test/ui/card_motion_test.dart — a moved card slides: between at 90 ms, landed at 180 ms

### T958 — The phone's Remove animations
Steps:
- Turn on the phone's Remove animations and play: deal, move, pause, win, change screens.
Expected: Every change is instant — no deal flight, slide, flip, cascade, fade or rise — and nothing is left half-drawn.
Core: no
Where: both
Automated: test/ui/ui_motion_test.dart — with the phone removing animations the first frame is the final one and navigating clears at once

## Filing a bug

A failed check becomes a GitHub issue under the `/n8-file` conventions: label
`bug` (plus `confirmed` once it has been reproduced), a `sev:*` label, the M6
milestone, and a sub-issue of epic #9. Severity (owner, round two of
`/n8-plan M6`, 2026-09-25): `sev:critical` crashes, loses a game or
statistics, or makes a game impossible to finish; `sev:high` misleads or
blocks play (a wrong rule, score or statistic, a broken TalkBack path, an
unreachable control) or visibly breaks the design on the S26 Ultra;
`sev:medium` is noticeable but harmless; `sev:low` is polish. The agent
assigns it when filing; only the owner changes it afterwards.

The issue names the check (`T213`), the run record, the build from Settings,
the device and whether it was hardware or an emulator, the deal number from
the pause card, the steps as run, what happened and what the check expected.
The run record's `bug` column then carries the issue number. A fix comes with
a test that was run against the unfixed code first and seen to fail.
