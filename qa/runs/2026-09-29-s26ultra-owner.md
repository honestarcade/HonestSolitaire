# Run record — 2026-09-29 · s26ultra · owner

- **Build:** v0.2.0 · BUILD 1021 — from release run 36340218909, installed
  from the Play internal test link (owner, 2026-09-29). The version string
  as read in Settings is still to be confirmed by the owner.
- **Device:** Samsung Galaxy S26 Ultra
- **Android / One UI:** not recorded
- **Hardware or emulator:** hardware
- **AVD and image:** n/a
- **Runs:** interim checklist (before qa/test-plan.md existed)
- **Run by:** owner, reporting in chat; transcribed by the agent (#115)

The owner's first play-through, run from an interim checklist page before
`qa/test-plan.md` (#111) was written, so the checks below cite that
checklist's sections and item numbers, not T-IDs. Checks it did not reach
are run later under the plan (#111, #115).

| check | result | bug |
|---|---|---|
| Interim · Main menu · item 1 | fail | #152 |
| Interim · Main menu · item 2 | fail | #153 |
| Interim · Starting a new Klondike · item 1 | fail | #152 |
| Interim · Starting a new Klondike · item 3 | skip | — |
| Interim · Starting a new Klondike · item 5 | fail | #154 |
| Interim · Statistics · item 1 | fail | #152 |
| Interim · remaining checklist items | pass (not flagged by the owner) | — |

## Findings, in the owner's words

Quoted as written on the checklist page, without correction.

**Main menu · item 1** ("Look at the menu on first-ever launch, no saved
game.") — fail, #152:

> Already started game. I don't see a way to abandon that game. So still says continue. But also, I auto-finished a game and it completed and showed me the completed card. Then go back to menu and still says "continue" and clicking on it takes me back to my game before I auto completed

**Main menu · item 2** (every menu row present and tappable) — fail, #153:

> Everything works, however teh github link needs to go directly to his game, not just honestarcade. https://github.com/honestarcade/HonestSolitaire

**Starting a new Klondike · item 1** (every draw, scoring and timer
option) — fail, #152:

> Finished (won) games don't track as won in statistics. Everything seems to work

**Starting a new Klondike · item 3** (the winnable search running past
5 s) — skip: not reachable by hand; #117 measures it.

> I couldn't get this to happen. It would find a hand in about a second or less

**Starting a new Klondike · item 5** (Keep playing) — fail, #154:

> It's there... at the bottom and easy to miss. Make it a more pop "color"

**Statistics · item 1** — fail, #152:

> As stated before, doesn't record wins

The owner closed the run with "Completed testing"; no other checklist item
was flagged.
