# Honest Solitaire

Klondike and Spider solitaire for Android phones, fully offline — a Flutter
app (Dart) built on `honestarcade/android-studio-app-template`, the
infrastructure extracted from Honest Sudoku. Build with
`flutter pub get && flutter run`.

The design source is the claude.ai/design project `88279a49-c9f2-46fd-996c-c1fa9ca3a41e`,
file `Honest Solitaire.dc.html` (read it with the `claude_design` MCP / DesignSync
`get_file`). It holds every screen, the prototype game rules, the settings
list and the brand sheet; `.n8/config.yml` records it as `design_source`.

The quality gate is **`tools/gate.sh`** — one command running the six steps CI
runs, in order: dependencies against the lockfile, `dart analyze --fatal-infos`,
format check, `flutter test` (which includes the invariant guards below), the
release bundle build, and `tools/check_aab.sh` over that bundle. It must print
`GATE PASSED` before anything is considered done.

CI runs one more thing the gate does not: **`tools/mutation_check.py`**, its own
job, which reintroduces every known defect one at a time and requires the guard
suite to catch each — naming the assertion that must fire, so a mutation that
merely turns the suite red some other way is reported as WRONG-REASON rather
than a pass. It refuses to run on a dirty tree and restores through a
`try/finally`. Run it locally before changing a guard: a guard weakened by
accident is the failure that mechanism exists to catch, and a green suite is
not evidence that the suite can fail. **Adding a guard means adding its
mutation.**

A comment may say *why*. A claim about what the code does *now* belongs in the
`reason:` of an assertion, where it is executed; a claim about anything else —
history, a measurement, another tool's output, a count — carries a date and a
source in the same sentence, or is cut. Neither half is optional: a `reason:`
cannot hold a fact about history or a measurement, and a sentence with no date
and no source is the one nothing re-reads. Where a count can be computed, cut
it and name the command instead. When a change is reverted or narrowed, the
comments it added are part of the revert.

This rule is carried over from Honest Sudoku, where repeated verification
rounds found new violations of it — including inside the very passes meant to
fix the previous violations. Treat it as a standing hazard on any project, not
a one-time cleanup. The one thing that reliably worked there: moving a claim
into something executed rather than into a better-written sentence — see
`test/guards/dependency_policy_example_test.dart`'s own pubspec.yaml check and
`test/guards/manifest_permission_example_test.dart`'s real-manifest check for
the pattern; neither can rot silently, because a test either runs green
against reality or it doesn't.

## Project invariants

Load-bearing constraints no story may breach without an explicit conversation
with the project owner. Changing one is plan drift by definition: log it as an
ad-hoc ledger entry in `.n8/decisions.md` and suggest `/n8-replan`.

1. **No ads, no tracking, no analytics, no network.** The release build
   declares no Android permissions at all (INTERNET included) and all player
   data stays on the device. Fonts are bundled, never fetched. Build-time
   permission removal rules are forbidden: a plugin that declares a permission
   is not adopted. *(test-enforced: `test/guards/manifest_permission_example_test.dart`
   over the source manifest and `tools/check_aab.sh` over every built bundle —
   guard: M0)*
2. **Lean dependencies.** A third-party package is added only when necessary,
   carries a trailing `# why: <reason>` on its key line in `pubspec.yaml`, and
   never brings ads, analytics, or network access. The SDK entries (`flutter`,
   `flutter_test`, `flutter_localizations`) and `flutter_lints` are exempt from
   the justification. *(blocklist test-enforced:
   `test/guards/dependency_policy_example_test.dart` — guard: M0; the
   justification line is honor-system until M2's guard story)*
3. **Deals are generated on the device, from a seed, deterministically.** The
   same seed and options (game, draw count or suit count) always produce the
   same deal, in any build. No deal is bundled. *(planned: M2 engine guard)*
4. **"Winnable deals only" is honest.** With that option on, every deal the
   app hands out has been proven solvable by the on-device solver before it is
   shown; with it off, the deal is a true uniform shuffle. *(planned: M2
   engine guard)*

## n8SDLC project

This project is managed by the n8SDLC workflow (GitHub Issues = the plan;
`/n8-stat` shows where things stand). If a change made in this session
deviates from what planned issues assume — different library, provider,
architecture, dropped/added scope, or amending a declared invariant below —
do two things before finishing:
1. Append an `## Ad-hoc` entry to `.n8/decisions.md` (format documented in
   that file's header) naming the change, the why, and the milestones/issues
   likely affected.
2. Tell the user which future milestones may now have stale plans and
   suggest running `/n8-replan`.

Separately: if a `/n8-*` skill's own instructions failed, misled you, or were
silent on something this session, tell the user and offer `/n8-feedback` —
it packages the learning as an issue on the plugin repo, stripped of project
specifics, and sends nothing until the user has reviewed the exact text.
