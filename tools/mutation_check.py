#!/usr/bin/env python3
"""Apply known defects to the repository and require the guard suite to catch each.

Extracted from Honest Sudoku, where repeated verification rounds found guards
that were written, believed, and then shown to be substring checks or scoped
to one job. The only thing that reliably told anyone so was mutating the code
and watching the suite stay green -- which is what this file automates.

Each entry is a defect this project's guards must catch, with the issue that
found it. The battery fails if the suite does NOT go red. The harness's own
comments below cite Honest Sudoku's issue numbers (#160, #172, #207, #213,
#217, #229, #238, #245...) as the historical record of why each piece of this
mechanism exists -- they are not live links in this repository, and nothing
here depends on them resolving anywhere. Read them as worked examples of the
failure each safeguard prevents.

Two rules learned the hard way:

  * A mutation must really change the file. A pattern that no longer matches
    silently tests nothing (#160).
  * A mutation of a YAML file must leave it PARSEABLE. A mutation that breaks
    the syntax makes the guard fail for the wrong reason and reports a false
    pass -- which is exactly what #172 was: `replaceFirst` inserted a literal
    `$1`, the YAML broke, and the battery called it caught.

Usage:  tools/mutation_check.py [--list] [--only SUBSTRING]
Exit:   0 every mutation was caught
        1 at least one survived (the suite stayed green)
        2 the battery could not run (dirty tree, bad pattern, unparseable)
"""
from __future__ import annotations

import argparse
import json
import dataclasses
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# The guard suite, minus any `slow`-tagged test.
#
# ONE test carries it: `the flag the workflow sets is the flag the guard
# reads`, which spawns a child `flutter test` (#245). So this excludes
# exactly that one, and the entry that needs it sets `slow=True`. The
# machinery stays because the reason for it is real and was measured: a guard
# whose input is expensive is run once per mutation, and a 45s test turns a
# 20-minute battery into 90. When the next expensive guard arrives it tags
# itself and the mutations that need it set `slow=True` (#229).
SUITE = ["flutter", "test", "--no-pub", "--tags", "guard",
         "--exclude-tags", "slow"]
SUITE_SLOW = ["flutter", "test", "--no-pub", "--tags", "guard"]
IN_FLIGHT = ROOT / ".mutation_check_in_flight"


@dataclasses.dataclass(frozen=True)
class Mutation:
    issue: str
    name: str
    path: str
    apply: object  # str -> str
    why: str
    expect: str = ""
    also: tuple = ()
    slow: bool = False
    creates: tuple = ()
    """A substring of the reason the RIGHT assertion prints when it fires.

    Without this the battery measures "the suite went red", which is not the
    same as "this guard caught it" -- the first version of this file reported
    two mutations as caught when what had actually failed was an unrelated
    test that happens to read the same file. That is the mistake the battery
    exists to find, made by the battery.

    `creates` names paths the mutated code WRITES while the suite runs, so
    they can be removed afterwards. Restoring the mutated file is not enough:
    the workspace mutation makes a script drop a password into the repository
    root, that file outlived the run, and it was then swept into a commit by
    `git add -A` -- twice. Being tracked, it went into the leak scan's skip
    set and blinded the very guard the mutation exists to exercise (#213).

    `also` carries further `(path, apply)` edits. Some defects are not
    expressible in one file: #203 is "a second parse path is added AND the
    rules are repointed at it", and the one-file version -- repoint the rules
    at a method that does not exist -- only breaks the compile. That reported
    WRONG-REASON, correctly, for two rounds. A mutation that cannot be written
    truthfully is not a mutation.
    """


def sub(pattern: str, replacement: str, count: int = 1, flags: int = 0):
    """A regex substitution that must match, with the group expansion Dart's
    replaceFirst does NOT do (#172)."""

    def go(text: str) -> str:
        out, n = re.subn(pattern, replacement, text, count=count, flags=flags)
        if n == 0:
            raise LookupError(f"pattern never matched: {pattern!r}")
        return out

    return go


def append(block: str):
    return lambda text: text.rstrip("\n") + "\n" + block


def chain(*steps):
    """Several substitutions on one file, in order.

    A defect that MOVES something is two edits, and writing it as one -- a
    delete without the matching insert -- tests a different defect than its
    name claims (#207: the deletion left every refusal working, so the
    ordering assertion correctly stayed silent).
    """

    def go(text: str) -> str:
        for step in steps:
            text = step(text)
        return text

    return go


MUTATIONS: list[Mutation] = [
    # This list starts with ONE worked example and is otherwise EMPTY. That is
    # deliberate: copying another app's defect history into a fresh repo would
    # be copying its bugs, not its discipline. The discipline is "adding a
    # guard means adding its mutation" (CLAUDE.md) -- the first time a real
    # defect ships and gets caught by a new guard, that defect becomes the
    # second entry here, named after the issue that found it, exactly the way
    # this file's own history (visible in the harness comments above) grew
    # from one entry to a hundred and thirty-eight.
    #
    # The worked example below is real: it mutates the ported .github/
    # workflows/ci.yml so the gate step becomes advisory rather than
    # required, and requires the guard suite to notice. Delete it once
    # your own first real mutation lands, or keep it as a live
    # demonstration -- either is fine.
    Mutation("#0", "the gate step becomes advisory", ".github/workflows/ci.yml",
             sub(r"run: tools/gate\.sh$", "run: tools/gate.sh || true", flags=re.M),
             "CI would run the gate and ignore its verdict",
             # Caught by workflow_structure_example_test.dart's "the gate job
             # runs tools/gate.sh, not a paraphrase of it" -- the marker is
             # that test's own reason text, not a generic label, per this
             # file's own rule: a verdict is "the suite went red AND the
             # marker is in its output", never just "the suite went red".
             'no step runs tools/gate.sh exactly'),
    Mutation("#M0", "a package loses its justification", "pubspec.yaml",
             sub(r"^(  yaml: \S+) # why: .*$", r"\1", flags=re.M),
             "a third-party package would ship with no recorded reason",
             'missing-why: 1 offender'),
]


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, **kw)


def parses_as_yaml(path: pathlib.Path) -> bool:
    """A YAML mutation that breaks the syntax proves nothing (#172)."""
    if path.suffix not in {".yml", ".yaml"}:
        return True
    probe = run([
        "python3", "-c",
        "import sys\n"
        "try:\n"
        "    import yaml\n"
        "except ImportError:\n"
        "    sys.exit(3)\n"
        "yaml.safe_load(open(sys.argv[1]))\n",
        str(path),
    ])
    if probe.returncode == 3:
        return True  # no PyYAML here; the Dart guard will report a parse failure
    return probe.returncode == 0


def compiles_as_dart(paths: list[pathlib.Path]) -> bool:
    """The Dart half of the rule `parses_as_yaml` states for YAML (#203).

    A mutation that does not compile fails every test in the file at once,
    which is a red suite for a reason that has nothing to do with the guard
    being measured. YAML had this check from #172; Dart did not, and #203's
    mutation -- a call to a method that was never added -- spent two rounds
    reported as WRONG-REASON when the truth was that the battery could not
    apply it.
    """
    dart = [p for p in paths if p.suffix == ".dart"]
    if not dart:
        return True
    probe = run(["dart", "analyze", "--no-fatal-warnings", *[str(p) for p in dart]])
    return probe.returncode == 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--audit", action="store_true",
                    help="run the marker preflight alone and exit")
    ap.add_argument("--only", default="")
    args = ap.parse_args()

    selected = [m for m in MUTATIONS if args.only.lower() in
                f"{m.issue} {m.name} {m.path}".lower()]

    if args.list:
        for m in selected:
            print(f"{m.issue:<7} {m.path:<42} {m.name}")
        print(f"\n{len(selected)} mutations")
        return 0

    # A run that dies between "write the mutation" and "restore the file"
    # leaves a DEFECT in the working tree, and the next `git commit -a` sweeps
    # it into history. That happened: an owner-role grant on the CI service
    # account rode into a docs commit, and the working tree's later correction
    # hid it from the gate, because the gate reads the tree and not the commit.
    #
    # `finally` cannot cover a kill. A marker can: it outlives the process, so
    # an interrupted run is detectable by the next one instead of silent.
    if IN_FLIGHT.exists():
        print("mutation_check: a previous run did not restore these files:",
              file=sys.stderr)
        print(IN_FLIGHT.read_text().strip(), file=sys.stderr)
        print(f"Check them against HEAD (`git diff HEAD`) before committing "
              f"anything, then delete {IN_FLIGHT}", file=sys.stderr)
        return 2

    dirty = run(["git", "status", "--porcelain"]).stdout.strip()
    if dirty:
        print("mutation_check: refusing to run with uncommitted changes:", file=sys.stderr)
        print(dirty, file=sys.stderr)
        return 2

    # THE MARKERS, BEFORE ANY MUTATION.
    #
    # A verdict here is "the suite went red AND the marker is in its output".
    # A marker that is part of a TEST'S NAME is therefore no verdict at all:
    # the runner prints the names of the tests it runs, so such a marker is
    # present whatever happened, every entry carrying it scores `caught` for
    # any red suite, and none of them can ever report WRONG-REASON. Both
    # #217 entries carried `'overflow'` -- a substring of `every rule reports
    # a document that overflows the loader` (#238).
    #
    # Read from the json stream rather than from a run's printed output,
    # because that output is machine-dependent in a way this check must not
    # be. Measured 2026-09-22, `flutter test --no-pub --tags guard` piped to
    # a file: no CR bytes, and a longest line that moves with the tree and
    # the checkout path — 199 characters one day, 205 another, with a name
    # visibly cut in one run and whole in the next,
    # so whether a given test's name survives depends on the length of the
    # absolute path printed before it — which differs between this checkout
    # and a runner's. CI's reporter prints them whole. An output-based audit
    # would therefore refuse in one place and pass in the other, which is the
    # machine-dependence #217 was reverted for once already. The json stream
    # carries names and prints entire.
    #
    # The same run is the baseline assertion the battery never had: a suite
    # that is red before any mutation makes every verdict below meaningless.
    print("mutation_check: baseline and marker audit", flush=True)
    # SUITE_SLOW, the superset: a `slow`-tagged test is excluded from the
    # mutation runs, but its name and its prints are in the output of any run
    # that includes it, so auditing the smaller suite leaves them unchecked
    # (#244).
    base = run(SUITE_SLOW + ["--reporter", "json"])
    names: list[str] = []
    printed: list[str] = []
    suites: list[str] = []
    by_id: dict[str, str] = {}
    failed: list[str] = []
    for line in base.stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("type")
        if kind == "suite":
            # The PATH the runner prints before every test name. A marker
            # naming an unrelated test file passed the audit and scored
            # `caught` for a mutation with nothing to do with it (#250);
            # the relative part of these comes from the source, so checking
            # them is the same verdict everywhere.
            path = event.get("suite", {}).get("path", "")
            if path:
                suites.append(path)
        elif kind == "testStart":
            test = event.get("test", {})
            name = test.get("name", "")
            by_id[str(test.get("id"))] = name
            # `loading <path>` is the runner's own bookkeeping, not a test.
            if name and not name.startswith("loading "):
                names.append(name)
        elif kind == "print":
            # NOTE the environment-sensitivity, because it bit on the first
            # CI run: a print can be CONDITIONAL. `signing_guard_test.dart`
            # prints `... could not be reached` only where the Android SDK is
            # missing, which is true of this battery's job and false on a
            # developer's machine, so `'reached'` was vacuous in CI alone.
            # That is the audit being right rather than flaky -- a marker
            # that a run prints cannot discriminate IN THAT RUN -- and the
            # remedy is a marker distinctive enough that no message contains
            # it, never a looser check here.
            # What a test PRINTS is in a green run's output exactly as a test
            # name is, and a marker matching it is just as vacuous. This is
            # how `'permissions:'` shipped: `permissions_guard_test.dart`
            # prints `release-no-permissions: ... is absent` on every run, so
            # that entry scored `caught` for any red suite at all (#244).
            printed.append(event.get("message", ""))
        elif kind == "testDone" and event.get("result") != "success":
            failed.append(str(event.get("testID")))
    if base.returncode != 0:
        # The NAMES of what failed. This printed the tail of the json stream
        # once, which is progress events and names nothing an operator can act
        # on (#247).
        print("mutation_check: the suite is RED before any mutation, so no "
              "verdict below would mean anything. Failing:", file=sys.stderr)
        for tid in failed or ["(none reported -- run the suite directly)"]:
            print(f"  {by_id.get(tid, tid)}", file=sys.stderr)
        return 2
    # A floor against the reporter yielding almost nothing -- the marker
    # audit below would then pass by reading nothing, which is a false
    # "clean" verdict rather than a real one. `1` is the only floor that is
    # correct on day one, when the suite might legitimately have only a
    # handful of guard tests; it is deliberately not a real accounting
    # check. RAISE THIS as your own guard suite grows, to a number well
    # below its real size -- Honest Sudoku, the project this file was
    # extracted from, used 100 against a suite of about 440 guard tests
    # (roughly a fifth), which was enough to catch "the reporter silently
    # yielded thirteen names" while tolerating ordinary run-to-run noise.
    MIN_EXPECTED_TEST_NAMES = 1
    if len(names) < MIN_EXPECTED_TEST_NAMES:
        print(f"mutation_check: the json reporter yielded {len(names)} test "
              f"names, fewer than the MIN_EXPECTED_TEST_NAMES floor of "
              f"{MIN_EXPECTED_TEST_NAMES} -- the marker audit below would "
              f"pass by reading nothing", file=sys.stderr)
        return 2
    # And every message a guard COULD print, from the source. What actually
    # printed is environment-dependent -- `signing_guard_test.dart`'s
    # `could not be reached` appears only where no Android SDK is installed,
    # which made `'reached'` vacuous in CI and fine locally -- so the audit
    # reads the literals too and is the same verdict everywhere. Conservative
    # by construction: it may flag a marker that only MIGHT be printed, and
    # the remedy for that is a more distinctive marker, which always exists.
    printable: list[str] = []
    for source in sorted((ROOT / "test" / "guards").glob("*.dart")):
        text = source.read_text()
        # `printOnFailure` too: its text lands in the output exactly when the
        # suite is red, which is every run the battery judges. Both quote
        # styles, because Dart has two and the single-quote-only version
        # missed every `print("...")` (#250).
        for call in re.finditer(
                r"(?:print|printOnFailure|markTestSkipped)\(\s*(.*?)\);",
                text, re.S):
            printable.append(" ".join(
                re.findall(r"'([^']*)'|\"([^\"]*)\"", call.group(1))
                and [m[0] or m[1] for m in
                     re.findall(r"'([^']*)'|\"([^\"]*)\"", call.group(1))]
                or []))

    # And the runner's own chrome, which is in every run's output and in
    # none of the sources above: the file path before each name, the loading
    # lines, the counter and the closing line (#250).
    #
    # Both halves of the run, not only the green one. The verdict this audit
    # protects is read from a RED run, so the failure formatter's own
    # vocabulary is the half that matters and was missing: `'Expected:'`
    # passed the audit and then scored `caught` for a mutation it had nothing
    # to do with (#262). These come from package:test's expect formatter and
    # its reporters — a fixed list, written down once with where it came
    # from, rather than discovered one instance per round.
    #
    # Paths are compared RELATIVE to the repository root: the absolute form
    # refuses a marker here and passes it on a runner, which is the
    # machine-dependence the paragraph above says this avoids.
    chrome = [str(pathlib.Path(p).relative_to(ROOT))
              if str(p).startswith(str(ROOT)) else str(p)
              for p in suites] + [
        # package:test's reporters
        "loading ",
        "All tests passed!",
        "Some tests failed.",
        "Skipped tests",
        # package:matcher's failure formatter, present in every red run
        "Expected:",
        "Actual:",
        "Which:",
        "package:matcher",
        "package:flutter_test",
        "Test failed. See exception logs above.",
        # the compact reporter's counter and clock
        "00:0",
        "+0",
        "-1",
    ]

    haystack = [("a test's NAME", n) for n in names]
    haystack += [("what a test PRINTS", t) for t in printed]
    haystack += [("a message a test can print", t) for t in printable]
    haystack += [("the runner's own output", t) for t in chrome]
    vacuous = [
        (m, kind, text)
        for m in selected
        if m.expect
        for kind, text in haystack
        if m.expect in text
    ]
    if vacuous:
        print("mutation_check: these markers are in the output of a GREEN "
              "run, so they are present whether or not the guard fired:",
              file=sys.stderr)
        for m, kind, text in vacuous:
            print(f"  {m.expect!r}  ({m.issue} {m.name})", file=sys.stderr)
            print(f"      matches {kind}: {text.strip()[:110]}", file=sys.stderr)
        print("Use a prefix of the assertion's own reason -- `leak:`, "
              "`overflow:` -- which nothing green prints.", file=sys.stderr)
        return 2
    if args.audit:
        print(f"{len(selected)} markers audited against {len(names)} test "
              f"names, {len(printed)} printed lines, {len(printable)} "
              f"messages a guard can print and {len(chrome)} lines the "
              f"runner itself emits; none of them matches")
        return 0

    print(f"mutation_check: {len(selected)} mutations\n")
    survived: list[Mutation] = []
    wrong: list[Mutation] = []
    broken: list[tuple[Mutation, str]] = []

    for i, m in enumerate(selected, 1):
        edits = [(m.path, m.apply), *m.also]
        targets = [ROOT / path for path, _ in edits]
        originals = [target.read_text() for target in targets]
        label = f"[{i}/{len(selected)}] {m.issue} {m.name}"
        try:
            mutated = [apply(text) for (_, apply), text in zip(edits, originals)]
        except LookupError as exc:
            broken.append((m, str(exc)))
            print(f"  BROKEN  {label}\n          {exc}")
            continue
        if mutated == originals:
            broken.append((m, "changed nothing"))
            print(f"  BROKEN  {label}\n          changed nothing")
            continue

        # The third source of a vacuous marker, and the one no baseline run
        # can show: the mutation's OWN inserted text. A guard that prints the
        # offending line puts that text into the output, so a marker matching
        # it is present because the mutation ran, not because the guard fired
        # (#244).
        if m.expect:
            added = "\n".join(
                line
                for new, old in zip(mutated, originals)
                for line in new.splitlines()
                if line not in old.splitlines()
            )
            if m.expect in added:
                broken.append((m, "the marker is in the text this mutation "
                                  "inserts, so a guard that echoes the "
                                  "offending line satisfies it"))
                print(f"  BROKEN  {label}\n          marker {m.expect!r} is in "
                      f"this mutation's own inserted text")
                continue

        IN_FLIGHT.write_text(
            f"{m.issue} {m.name}\n"
            + "".join(f"  {path}\n" for path, _ in edits)
        )
        for target, text in zip(targets, mutated):
            target.write_text(text)
        try:
            unparseable = [t for t in targets if not parses_as_yaml(t)]
            if unparseable:
                broken.append((m, "left the file unparseable — it would fail for the wrong reason"))
                print(f"  BROKEN  {label}\n          unparseable after mutation")
                continue
            if not compiles_as_dart(targets):
                broken.append((m, "left the Dart unanalyzable — it would fail for the wrong reason"))
                print(f"  BROKEN  {label}\n          does not compile after mutation")
                continue
            suite = SUITE_SLOW if m.slow else SUITE
            result = run(suite)
            output = result.stdout + result.stderr
            if result.returncode == 0:
                # Re-run before reporting a survivor. A SURVIVED verdict is
                # the one that matters — it says a guard has a hole — and one
                # flaky green would announce a hole that is not there, or
                # worse, be dismissed as flake when it is real. A second
                # green costs one suite run on the rare path only (#192).
                confirm = run(suite)
                if confirm.returncode != 0:
                    output = confirm.stdout + confirm.stderr
                    print(f"  (first run of {label} was green, second was not "
                          f"— reporting the second)")
                else:
                    survived.append(m)
                    print(f"  SURVIVED {label}\n           {m.why}")
            if result.returncode == 0 and m not in survived:
                # Fell through from the flaky branch above; judged on the
                # confirming run's output.
                if m.expect and m.expect not in output:
                    wrong.append(m)
                    print(f"  WRONG-REASON {label}\n               the suite "
                          f"failed, but not with {m.expect!r}")
                else:
                    print(f"  caught  {label}")
            elif result.returncode == 0:
                pass
            elif m.expect and m.expect not in output:
                # Red, but not for this reason. Counting it as caught is how a
                # guard gets credit for an assertion it does not make.
                wrong.append(m)
                print(f"  WRONG-REASON {label}\n               the suite failed, "
                      f"but not with {m.expect!r}")
            else:
                print(f"  caught  {label}")
        finally:
            for target, text in zip(targets, originals):
                target.write_text(text)
            for made in m.creates:
                (ROOT / made).unlink(missing_ok=True)
            IN_FLIGHT.unlink(missing_ok=True)

    print()
    if broken:
        print(f"{len(broken)} mutation(s) could not be applied — the battery is "
              f"testing less than it claims:", file=sys.stderr)
        for m, why in broken:
            print(f"  {m.issue} {m.name}: {why}", file=sys.stderr)
    if wrong:
        print(f"{len(wrong)} mutation(s) failed the suite for the WRONG REASON — "
              f"the named assertion did not fire:", file=sys.stderr)
        for m in wrong:
            print(f"  {m.issue} {m.path}: {m.name} (expected {m.expect!r})",
                  file=sys.stderr)
    if survived:
        print(f"{len(survived)} mutation(s) SURVIVED — the guards do not catch them:",
              file=sys.stderr)
        for m in survived:
            print(f"  {m.issue} {m.path}: {m.name}", file=sys.stderr)
    if broken or survived or wrong:
        return 1 if (survived or wrong) else 2
    print(f"all {len(selected)} mutations caught")
    return 0


if __name__ == "__main__":
    sys.exit(main())
