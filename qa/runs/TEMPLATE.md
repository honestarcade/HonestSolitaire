# Run record — YYYY-MM-DD, <device>, <who>

Copy this file to `qa/runs/YYYY-MM-DD-<device>-<who>[-n].md`: `<device>` is
`s26ultra`, `emu-api24` or `emu-dev`; `<who>` is `owner` or `agent`; `-2`,
`-3` mark a second or third run the same day. Fill every field; write `n/a`
where one does not apply. Checks are listed in `qa/test-plan.md`.

- Build: <the version line from Settings, e.g. v0.2.0 · BUILD 2>
- Device: <Samsung Galaxy S26 Ultra, or the emulator's device profile>
- Android / One UI: <the Android version and, on the phone, the One UI version; emulators: the API level>
- Hardware or emulator: <hardware | emulator>
- AVD and image: <emulators: the AVD name and system image; hardware: n/a>
- Runs: <the sampling rows covered, e.g. R1, R5>
- Run by: <owner | agent; for an owner run the agent transcribes from chat>

Results are `pass`, `fail`, `skip`, `blocked` or `n-a`. A `fail` names its
issue in `bug`; a `blocked` names what blocked it.

| check | result | bug |
|---|---|---|
| T001 | | |

## Notes

Times, deal numbers and anything a check asks to be written down.
