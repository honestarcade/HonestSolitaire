# Listening checklist (#115)

How to hear every sound the game makes, and feel every haptic tick, on the
phone — so each clip can be kept or sent back for a new round.

The deals and move lines below are not typed by hand.
`dart run tools/find_listening_deals.dart` found the deals (the shortest
lines it could find), and `test/qa/listening_test.dart` replays each line
through the game controller with sound and haptics attached: it fails if any
line below differs from what the game really does, or if a trigger listed
here is not reached. The word after each dash is the clip the game plays for
that move.

## Before you start

In **Settings**:

- **Sound effects** on, **Haptics** on.
- **Auto-finish** **off** — with it on, the last cards sweep up on their
  own and a King placed by the sweep does not chime (only the win does).
- **Auto-flip cards** on, **Card animations** on.
- **One-tap move** off, so a card goes where the line says rather than to
  the best spot. (Dragging works either way.)
- **Background music** off for now; the music has its own section.

Media volume up, and the phone not on silent. Put the settings back
afterwards if you prefer them otherwise.

Reading a line: "Drew ten of diamonds" means tap the stock; "Nine of
diamonds to column 5" means move that card — with any cards on top of it
("and 2 more") — to column 5, counting columns from the left; "to clubs
foundation" means onto that suit's foundation. "Card turned" is the
face-down card that flips over as a result.

## What to listen for

| Clip | When it plays | Where below |
|---|---|---|
| deal | a new deal appears; a Spider row is dealt | Klondike start, Spider start, Spider lines 1, 2, 5, 8 |
| flip | a face-down card turns over | Klondike line 1 onwards |
| snap | a card lands and nothing turns over; a stock tap | Klondike line 10 onwards |
| chime | (1) a Klondike foundation reaches its King by hand | Klondike line 76 |
| chime | (2) the game is won (the last card of FINISH's sweep) | Klondike, after FINISH |
| chime | (3) a Spider run completes | Spider line 10 |
| music | the loop, while a board is showing | Music section |

A move that turns a card plays the flip, not the snap; one sound per move.

## Klondike — Deal **81**

**New Klondike**: Draw 1, Standard scoring, either timer, the random (not
winnable-only) deal, and **81** in the deal-number field; start the deal.

- The deal appearing plays the **deal** clip.

Then play lines 1–36. After line 36 every card on the board is face up and
**FINISH** appears in the tool row — do not tap it yet.

1. Ace of clubs to clubs foundation. Card turned: eight of clubs — flip
2. Two of clubs to clubs foundation. Card turned: three of hearts — flip
3. Three of hearts to column 2. Card turned: ace of hearts — flip
4. Ace of hearts to hearts foundation. Card turned: nine of diamonds — flip
5. Nine of diamonds to column 5. Card turned: six of hearts — flip
6. Eight of clubs to column 5. Card turned: seven of spades — flip
7. Queen of hearts to column 4. Card turned: jack of hearts — flip
8. Six of hearts to column 3. Card turned: jack of spades — flip
9. Jack of hearts to column 1. Card turned: nine of clubs — flip
10. Drew ten of diamonds — snap
11. Ten of diamonds to column 6 — snap
12. Nine of clubs to column 6. Card turned: jack of diamonds — flip
13. Ten of spades and 2 more to column 7. Card turned: six of clubs — flip
14. Jack of spades and 2 more to column 4 — snap
15. King of spades and 4 more to column 6. Card turned: five of hearts — flip
16. Five of hearts to column 5. Card turned: seven of diamonds — flip
17. Seven of diamonds to column 7. Card turned: six of diamonds — flip
18. Four of clubs and 1 more to column 5. Card turned: nine of spades — flip
19. Six of clubs and 3 more to column 7. Card turned: nine of hearts — flip
20. Drew ace of spades — snap
21. Ace of spades to spades foundation — snap
22. Drew seven of clubs — snap
23. Drew eight of diamonds — snap
24. Eight of diamonds to column 2 — snap
25. Seven of spades and 1 more to column 2 — snap
26. Drew king of diamonds — snap
27. King of diamonds to column 3 — snap
28. Drew eight of spades — snap
29. Drew five of diamonds — snap
30. Drew queen of spades — snap
31. Queen of spades to column 3 — snap
32. Jack of diamonds and 8 more to column 3. Card turned: three of clubs — flip
33. Three of clubs to clubs foundation. Card turned: two of hearts — flip
34. Two of hearts to hearts foundation. Card turned: ten of clubs — flip
35. Nine of hearts to column 7. Card turned: ace of diamonds — flip
36. Ace of diamonds to diamonds foundation. Card turned: two of diamonds — flip

**Chime (1), a King by hand.** Now keep playing by hand — cards up to the
foundations, stock taps when stuck — until the first King goes onto a
foundation: that move **chimes** and ticks. Any route works; one that the
test replays is lines 37–76, where the King of hearts goes up.

<details>
<summary>Lines 37–76 (optional)</summary>

37. Three of hearts to hearts foundation — snap
38. Four of clubs to clubs foundation — snap
39. Drew king of hearts — snap
40. Drew three of spades — snap
41. Drew two of spades — snap
42. Two of spades to spades foundation — snap
43. Three of spades to spades foundation — snap
44. Two of diamonds to diamonds foundation — snap
45. Drew king of clubs — snap
46. King of clubs to column 5 — snap
47. Drew seven of hearts — snap
48. Drew five of spades — snap
49. Five of spades to column 4 — snap
50. Drew queen of diamonds — snap
51. Drew five of clubs — snap
52. Five of clubs to clubs foundation — snap
53. Drew six of spades — snap
54. Drew four of hearts — snap
55. Four of hearts to hearts foundation — snap
56. Five of hearts to hearts foundation — snap
57. Six of clubs to clubs foundation — snap
58. Six of hearts to hearts foundation — snap
59. Six of spades to column 3 — snap
60. Queen of diamonds to column 5 — snap
61. Seven of hearts to hearts foundation — snap
62. Drew eight of hearts — snap
63. Eight of hearts to hearts foundation — snap
64. Nine of hearts to hearts foundation — snap
65. Six of diamonds and 1 more to column 2 — snap
66. King of hearts to column 4 — snap
67. Drew jack of clubs — snap
68. Drew four of diamonds — snap
69. Drew four of spades — snap
70. Four of spades to spades foundation — snap
71. Drew ten of hearts — snap
72. Ten of hearts to hearts foundation — snap
73. Jack of hearts to hearts foundation — snap
74. Jack of spades and 2 more to column 5 — snap
75. Queen of hearts to hearts foundation — snap
76. King of hearts to hearts foundation — chime

</details>

**Chime (2), the win.** Tap **FINISH**. The sweep lands each remaining card
with a **snap** (its Kings do not chime), and the last card — the win —
**chimes** once.

## Spider — Deal **3**

**New Spider**: One suit, Strict empty-column rule, either timer, and **3**
in the deal-number field; start the deal.

- The deal appearing plays the **deal** clip.
- "Dealt a row" is a tap on the stock (or **DEAL** in the tool row): it
  plays the **deal** clip too.

1. Dealt a row, 4 left — deal
2. Dealt a row, 3 left — deal
3. Nine of spades to column 9 — snap
4. Eight of spades and 1 more to column 9. Card turned: four of spades — flip
5. Dealt a row, 2 left — deal
6. Ten of spades and 4 more to column 7 — snap
7. Jack of spades and 5 more to column 2 — snap
8. Dealt a row, 1 left — deal
9. Four of spades and 2 more to column 2. Card turned: seven of spades — flip
10. Ace of spades to column 2. Run completed, spades — chime

**Chime (3), a run.** Line 10 completes King-to-Ace in column 2: the run
leaves the board with a **chime** and a tick.

## Music

1. Settings → **Background music** on. Open any game: the loop starts.
2. Let it run past 30 seconds and listen at the join — the loop should
   repeat with no click or gap.
3. It should sit under the effects, not over them: play a few moves while
   it runs.
4. It pauses (not restarts) when you pause the game, leave to the menu or
   switch apps, and carries on from where it was when you come back.
5. **NEW** or **RESTART** starts it again from the top.
6. With another app's audio playing (a podcast, say), the game's music does
   not start over it.

A problem with steps 4–6 is a bug in how the music behaves, filed as a bug —
not a reason to regenerate the loop.

## Haptics

With **Haptics** on, you should feel one short tick — and only then — when:

- a move is refused (drop a card where it cannot go; it springs back);
- a Klondike foundation reaches its King (Chime 1 above) or a Spider run
  completes (Chime 3 above);
- you long-press a column to peek at it.

An ordinary move, a draw and a deal do not tick. Turning **Haptics** on in
Settings gives one sample tick; turning **Sound effects** on plays a sample
snap.

The test replays a refused move and a peek as well and checks that each
ticks once, and that an ordinary move does not. The tick goes through
Android's own touch feedback, so its strength follows the phone's
touch-feedback setting. A missing, doubled or wrong-moment tick is a bug,
filed as one.

## Your verdicts

For each of deal, flip, snap, chime and music, tell the agent **keep
<clip>**, or what is wrong with it in your own words. Only an explicit
"keep" counts. A clip that is only too loud or too quiet is re-levelled and
heard again, not regenerated. Anything else gets three new versions from a
new prompt to choose from, round after round until one is kept. The verdicts
go in their own run record, in a table
`clip | round | variant | verdict | owner's words`.
