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
# Guards whose input is an expensive child pipeline (bash, zip, keytool)
# carry it — `grep -l "'slow'" test/guards/*.dart` lists them; a guard that
# only shells out to `git` does not. Honest Sudoku introduced the tag for a
# guard that spawned a child `flutter test` (its #245). The entries whose
# guard needs one set `slow=True`. The machinery stays because the reason
# for it is real and was measured: a guard whose input is expensive is run once per mutation, and a 45s test turns a
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
    deletes: str = ""
    replaces_with: tuple = ()
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

    `deletes` names one file removed for the run and `replaces_with` is a
    `(target, fixture)` pair whose fixture bytes overwrite the target (#97)
    -- or, when the target is also in `creates`, become a file that was not
    there before and is removed afterwards (#111: a misnamed run record):
    the defects a text substitution cannot express -- a missing raster, the
    template's icon back in place. Both are byte snapshots restored in the
    same try/finally as the text edits; tools/test_mutation_check.py holds
    the round trip byte-identical. A mutation of these kinds may leave
    `path` empty.

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
    Mutation("#28", "the app stops being portrait-only",
             "android/app/src/main/AndroidManifest.xml",
             sub(r'\n\s*android:screenOrientation="portrait"', ""),
             "the app would rotate, which the design never lays out",
             'android-identity: MainActivity is not locked to portrait'),
    Mutation("#29", "a wrong package is reported as a permission",
             "tools/check_aab.sh",
             sub(r'(echo "PACKAGE MISSING: expected \$PACKAGE in \$AAB" >&2\n)  exit 2\n',
                 r"\1"),
             "a wrong package id would be misdiagnosed as permissions",
             'bundle-scan: a wrong package was not diagnosed as one',
             slow=True),
    Mutation("#30", "the bundle scan waves through a third-party request",
             "tools/check_aab.sh",
             sub(r'  else\n    OFFENDERS="\$OFFENDERS\$name\n"\n  fi\ndone <<EOF\n\$PERM_ENTRIES',
                 '  else\n    :\n  fi\ndone <<EOF\n$PERM_ENTRIES'),
             "an SDK's own permission request would ship past the scan",
             'bundle-scan: a third-party permission request was not refused',
             slow=True),
    Mutation("#31a", "the main manifest declares a permission",
             "android/app/src/main/AndroidManifest.xml",
             sub(r'(<manifest [^>]*>\n)',
                 r'\1    <permission android:name="com.honestarcade.solitaire.P" />\n'),
             "a permission declaration would ship, and only the bundle scan would see it",
             'manifest-permission-element: 1 offender'),
    Mutation("#31b", "a manifest strips a permission at build time",
             "android/app/src/debug/AndroidManifest.xml",
             sub(r'<uses-permission android:name="android.permission.INTERNET"/>',
                 '<uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>'),
             "a removal rule would hide a plugin's permission instead of refusing the plugin",
             'manifest-removal-rule: 1 offender'),
    Mutation("#32", "a blocked package hides behind a commented header",
             "pubspec.yaml",
             sub(r'^dev_dependencies:$',
                 'dev_dependencies: # test only\n  google_mobile_ads: ^5.0.0 # why: mutation',
                 flags=re.M),
             "an ads SDK would pass the dependency guard",
             'dependency-policy: 1 offender'),
    Mutation("#33a", "a release request without every key debug-signs",
             "android/app/build.gradle.kts",
             sub(r'if \(hsReleaseRequested && !hsSigningComplete\) \{\n[^\n]*\n[^\n]*\n\}\n', ""),
             "HS_RELEASE=1 with a missing secret would build a debug-signed bundle",
             'signing-fail-closed: 1 offender'),
    Mutation("#33b", "git stops ignoring keystores",
             ".gitignore",
             sub(r'^\*\.keystore\n', "", flags=re.M),
             "a keystore dropped in the tree could be committed",
             'key-material-not-ignored:'),
    Mutation("#34", "the gate exits 0 after a failing step",
             "tools/gate.sh",
             sub(r'(echo "GATE FAILED at \$label \(exit \$status\)" >&2\n)    exit "\$status"',
                 r'\1    exit 0'),
             "a failing gate would read as a pass to CI",
             'gate-failure-path: a failing step did not fail the gate',
             slow=True),
    Mutation("#44", "the Play upload names a typo'd package",
             ".github/workflows/release.yml",
             sub(r"packageName: com\.honestarcade\.solitaire",
                 "packageName: com.honestarcde.solitaire"),
             "the release would upload to, or fail against, the wrong app",
             'android-identity-workflow: 1 offender'),
    Mutation("#47", "a variant manifest declares a permission",
             "android/app/src/profile/AndroidManifest.xml",
             sub(r'(<manifest [^>]*>\n)',
                 r'\1    <permission android:name="com.honestarcade.solitaire.P" />\n'),
             "a permission declared outside main would pass the source guard",
             'manifest-permission-element: 1 offender'),
    Mutation("#35", "the keystore step turns on shell tracing",
             ".github/workflows/release.yml",
             sub(r'(      - id: keystore\n        name: Decode the upload keystore\n'
                 r'        env:\n[^\n]*\n        run: \|\n)          set -euo pipefail',
                 r'\1          set -x\n          set -euo pipefail'),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure: 1 offender'),
    Mutation("#36a", "the release stops waiting for the gate",
             ".github/workflows/release.yml",
             sub(r'^    needs: gate\n', "", flags=re.M),
             "a tag could ship a bundle the gate never passed",
             'release-order: 1 offender'),
    Mutation("#36b", "the release stops checking the certificate",
             ".github/workflows/release.yml",
             sub(r'      - id: cert\n        name: Verify the signing certificate\n'
                 r'        run: tools/verify_upload_cert.sh\n\n', ""),
             "a bundle signed by the wrong key would be uploaded",
             'release-order: 1 offender'),
    Mutation("#38", "the release workflow stops creating the GitHub release",
             ".github/workflows/release.yml",
             sub(r'      - id: release\n(?:(?!      - id: |      #).*\n)*', ''),
             "a tag pushed without a release would leave the attach nothing to attach to",
             'release-order create step missing'),
    Mutation("#113", "the bundle scan waves through a debuggable build",
             "tools/check_aab.sh",
             sub(r'DEBUGGABLE_RUNS="\$\(printf [^\n]*\n', 'DEBUGGABLE_RUNS=""\n'),
             "a debuggable bundle would ship past the scan",
             'bundle-scan: a debuggable bundle was not refused',
             slow=True),
    Mutation("#37", "the certificate check accepts any signed bundle",
             "tools/verify_upload_cert.sh",
             sub(r'if \[ "\$BUNDLE_FP" = "\$PEM_FP" \]; then',
                 'if [ -n "$BUNDLE_FP" ]; then'),
             "a foreign-key bundle would read as MATCH",
             'release-scripts: a foreign-key bundle passed',
             slow=True),
    Mutation("#39", "the mutations check becomes advisory",
             ".github/workflows/ci.yml",
             sub(r"run: tools/mutation_check\.py$",
                 "run: tools/mutation_check.py || true", flags=re.M),
             "a surviving mutation would leave the required check green",
             'workflow-structure: no step runs tools/mutation_check.py'),
    Mutation("#41", "play-api-check ignores a refused edit",
             ".github/workflows/play-api-check.yml",
             sub(r'if \[ "\$status" != "200" \]; then', 'if false; then'),
             "a 403 would print a green Play-access summary",
             'play-api-check: a 403 did not fail the check',
             slow=True),
    Mutation("#45a", "ship runs even when the gate failed",
             ".github/workflows/release.yml",
             sub(r'^    needs: gate\n', '    needs: gate\n    if: always()\n',
                 flags=re.M),
             "a tag could ship a bundle the gate refused",
             'release-order: 1 offender'),
    Mutation("#45b", "the mutations job is skipped",
             ".github/workflows/ci.yml",
             sub(r'^  mutations:\n', '  mutations:\n    if: false\n', flags=re.M),
             "a skipped job satisfies the required check",
             'workflow-skippable: 1 offender'),
    Mutation("#46", "every release step runs with tracing on",
             ".github/workflows/release.yml",
             sub(r'^(defaults:\n  run:\n    shell: )bash$', r'\1bash -x {0}',
                 flags=re.M),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure: 1 offender'),
    Mutation("#49", "the PR bundle is named after the merge ref again",
             ".github/workflows/ci.yml",
             sub(r'honest-solitaire-aab-\$\{\{ github\.event\.pull_request\.head\.sha \|\| github\.sha \}\}',
                 'honest-solitaire-aab-${{ github.sha }}'),
             "a PR's bundle could not be found from its head commit",
             'artifact-name: 1 offender'),
    Mutation("#37b", "ci_version.sh accepts a ref with a newline",
             "tools/ci_version.sh",
             sub(r'die "ref contains a newline"', 'true'),
             "a crafted tag could inject a line into the step's output",
             'release-scripts: ci_version.sh accepted',
             slow=True),
    Mutation("#41b", "play-api-check fails a brand-new app",
             ".github/workflows/play-api-check.yml",
             sub(r"\{ grep -oE '\"track\":\"\[a-z\]\+\"' \|\| true; \}",
                 "grep -oE '\"track\":\"[a-z]+\"'"),
             "the correct empty-tracks state would fail with no message",
             'play-api-check: a new app with no tracks failed the check',
             slow=True),
    Mutation("#41c", "set_ci_secrets uploads a mismatched key password",
             "tools/set_ci_secrets.sh",
             sub(r'\[ "\$KEY_PASS" = "\$KEYSTORE_PASS" \] \|\| \{', 'true || {'),
             "a password the release build cannot use would be uploaded",
             'setup-scripts: a key-password mismatch was uploaded',
             slow=True),
    Mutation("#53", "a keystore step traces through a bundled -o",
             ".github/workflows/release.yml",
             sub(r'(      - id: keystore_check\n(?:[^\n]*\n)*?          )set -euo pipefail',
                 r'\1set -euo xtrace'),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure: 1 offender'),
    Mutation("#54", "set_ci_secrets ignores a keystore it cannot open",
             "tools/set_ci_secrets.sh",
             sub(r'-alias "\$KEY_ALIAS" > /dev/null 2>&1 \|\| \{',
                 '-alias "$KEY_ALIAS" > /dev/null 2>&1 || true; false && {'),
             "a password that cannot open the keystore would be uploaded",
             'setup-scripts: a keystore the password cannot open was uploaded',
             slow=True),
    Mutation("#56a", "the keystore step's shell traces after a -O value",
             ".github/workflows/release.yml",
             sub(r'(      - id: keystore\n        name: Decode the upload keystore\n)',
                 r'\1        shell: bash -O extglob -x {0}\n'),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure .github/workflows/release.yml: '
             'ship/keystore: shell traces'),
    Mutation("#56b", "the keystore step's shell traces after a --long=value",
             ".github/workflows/release.yml",
             sub(r'(      - id: keystore\n        name: Decode the upload keystore\n)',
                 r'\1        shell: bash --rcfile=/dev/null -x {0}\n'),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure .github/workflows/release.yml: '
             'ship/keystore: shell traces'),
    Mutation("#56c", "the keystore step traces inside bash -c \"...\"",
             ".github/workflows/release.yml",
             sub(r'(      - id: keystore\n        name: Decode the upload keystore\n'
                 r'        env:\n[^\n]*\n        run: \|\n          set -euo pipefail\n)',
                 r'\1          bash -c "set -x; true"\n'),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure .github/workflows/release.yml: '
             'ship/keystore: shell tracing'),
    Mutation("#56d", "the keystore step traces inside bash -c $'...'",
             ".github/workflows/release.yml",
             sub(r'(      - id: keystore\n        name: Decode the upload keystore\n'
                 r'        env:\n[^\n]*\n        run: \|\n          set -euo pipefail\n)',
                 r"\1          bash -c $'true\\nset -x'\n"),
             "the keystore password would be echoed into a public log",
             'workflow-secret-exposure .github/workflows/release.yml: '
             'ship/keystore: shell tracing'),
    Mutation("#56e", "the secret scanner reads comments as commands",
             "test/guards/workflow_secrets_test.dart",
             sub(r"\} else if \(c == '#' && !inWord\) \{",
                 "} else if (c == '#' && !inWord && false) {"),
             "a commented-out `# set -x` would fail every workflow that "
             "explains why tracing is off",
             'workflow-secrets: clean line flagged'),
    Mutation("#57a", "set_ci_secrets stops checking the alias",
             "tools/set_ci_secrets.sh",
             sub(r' \\\n    -alias "\$KEY_ALIAS" > /dev/null 2>&1 \|\| \{',
                 ' > /dev/null 2>&1 || {'),
             "an alias the keystore does not hold would be uploaded",
             'setup-scripts: keytool -list does not check the alias',
             slow=True),
    Mutation("#57b", "set_ci_secrets puts the password on keytool's command line",
             "tools/set_ci_secrets.sh",
             sub(r'-storepass:env HS_PASS_PROBE', '-storepass "$KEYSTORE_PASS"'),
             "the keystore password would be visible in the process table",
             "setup-scripts: the keystore password is on keytool's command line",
             slow=True),
    Mutation("#57c", "set_ci_secrets checks the keystore is readable after uploading",
             "tools/set_ci_secrets.sh",
             chain(
                 sub(r'\[ -r "\$KEYSTORE_PATH" \] \|\| \{\n(?:[^\n]*\n)*?\}\n\n', ""),
                 sub(r'(printf \'%s\' "\$KEY_PASS" \| gh secret set HS_KEY_PASS -R "\$REPO"\n)',
                     r'\1[ -r "$KEYSTORE_PATH" ] || {\n'
                     r'  echo "set_ci_secrets: the keystore named in the credentials file is not readable:" >&2\n'
                     r'  echo "  $KEYSTORE_PATH" >&2\n'
                     r'  exit 2\n'
                     r'}\n'),
             ),
             "secrets naming a keystore that is not there would be uploaded",
             'setup-scripts: an unreadable keystore reached gh',
             slow=True),
    Mutation("#59", "the engine imports Flutter", "lib/engine/card.dart",
             sub(r"^library;\n", "library;\n\nimport 'package:flutter/foundation.dart';\n",
                 flags=re.M),
             "the engine would need a Flutter binding, so it could not run in a bare isolate",
             'engine-imports: 1 offender'),
    Mutation("#70a", "the shuffle is seeded from the clock", "lib/engine/rng.dart",
             sub(r"Rng\(int seed\) : _state = seed & _mask32;",
                 "Rng(int seed) : _state = (seed ^ DateTime.now().microsecond) & _mask32;"),
             "the same deal number would deal different cards on every device",
             'engine-determinism:'),
    Mutation("#70b", "the dealer marks a deal winnable without solving it",
             "lib/engine/winnable_dealer.dart",
             sub(r"final solution = result is Solved \? result\.moves : null;",
                 "final solution = result is Solved ? result.moves : const <Move>[];"),
             "every deal would be handed out as winnable with no proof",
             'engine-winnable: a deal marked winnable did not win',
             slow=True),
    Mutation("#117a", "the on-device golden copy drifts from the JSON",
             "integration_test/golden_deals.g.dart",
             sub(r"1: r'\{\"tableau\":\[\[\"3H\"\]", "1: r'{\"tableau\":[[\"4H\"]"),
             "the phone would be checked against deals the host never pinned",
             'engine-determinism: integration_test/golden_deals.g.dart drifted'),
    Mutation("#118-gate", "the M6 gate stops naming sev:high bugs",
             "tools/m6_gate.sh",
             sub(r'^    \*" sev:high "\*\) blocker "\$n" "sev:high" "\$t" ;;\n', "", flags=re.M),
             "a high bug would be reported as unrated, and M6 could close with it misfiled",
             'm6-gate: sev:high bug not reported'),
    Mutation("#170a", "a named game loses to the last game played",
             "lib/ui/widgets/game_tabs.dart",
             sub(r"^  if \(named != null\) return named;\n", "", flags=re.M),
             "Rules or Statistics from a pause card would open on the other game",
             'let the last game played override the named game'),
    Mutation("#170b", "the game in play loses to the last game played",
             "lib/ui/widgets/game_tabs.dart",
             sub(r"^  if \(c\.hasMove \|\| c\.game\.moves > 0\) return GameType\.of\(c\.game\);\n", "", flags=re.M),
             "a tabbed screen could open on a game other than the one being played",
             'the last game played overrode the game in play'),
    Mutation("#174a", "the audio guard stops listening for silence",
             "test/guards/audio_rules.dart",
             sub(r"if \(db < kMinRmsDbfs\) \{", "if (db < double.negativeInfinity) {"),
             "a silent placeholder clip would ship",
             'audio-level: a silent clip passed'),
    Mutation("#174b", "the audio guard stops comparing clips",
             "test/guards/audio_rules.dart",
             sub(r"if \(a\.length == b\.length && _same\(a, b\)\) \{", "if (a.length < 0 && _same(a, b)) {"),
             "one clip copied over another would ship",
             'audio-level: a copied clip passed'),
    Mutation("#169a", "the create step edits a release that already exists",
             ".github/workflows/release.yml",
             sub(r'echo "a GitHub release for \$TAG exists; leaving it untouched"',
                 'gh release edit "$TAG" --title retitled'),
             "a release /n8-release made, notes and all, would be overwritten",
             'an existing release was created or edited'),
    Mutation("#169b", "release candidates stop being prereleases",
             ".github/workflows/release.yml",
             sub(r"\*-\*\) flags\+=\(--prerelease --latest=false\) ;;", "*-*) ;;"),
             "a candidate would be marked Latest over the last final release",
             'a candidate was not made a prerelease'),
    Mutation("#169c", "a final release's notes start from the last candidate",
             ".github/workflows/release.yml",
             sub(r"\*\) describe\+=\(--exclude '\*-\*'\) ;;", "*) ;;"),
             "a final release's notes would leave out everything its candidates carried",
             "a final release's notes skip the candidates"),
    Mutation("#169d", "a failed run no longer marks its release",
             ".github/workflows/release.yml",
             sub(r'"\*\*This build did not reach Play:\*\* the release run failed',
                 '"The release run failed'),
             "a release page would read as shipped for a build Play never got",
             'a failed run left no mark'),
    Mutation("#169e", "the release is created before the bundle is checked",
             "test/guards/release_workflow_test.dart",
             sub(r"    if \(scan >= 0 && create < scan\) \{\n      violations\.add\('create step before the scan'\);\n    \}\n", ""),
             "a bundle that fails the scan would still get a release page",
             'release-order: a release page before the checks passed'),
    Mutation("#175a", "a run that reaches Play leaves the old mark",
             ".github/workflows/release.yml",
             sub(r'            gh release edit "\$TAG" --notes-file "\$RUNNER_TEMP/release-notes\.md"\n            echo "cleared',
                 '            echo "cleared'),
             "a shipped build's release would still say it did not reach Play",
             'a run that reached Play left the mark'),
    Mutation("#175b", "a second failure stacks a second mark",
             ".github/workflows/release.yml",
             sub(r" \|\n            sed '/\^\\\*\\\*This build did not reach Play:\\\*\\\*/,/\^\$/d'\)\"", ')"'),
             "a release re-run twice would carry the warning twice",
             'a second failure stacked a second mark'),
    Mutation("#175c", "a setup accent's text goes dark on its tint",
             "lib/ui/widgets/option_panel.dart",
             sub(r"^    text: Palette\.textViolet,$", "    text: Palette.violet,", flags=re.M),
             "Keep playing and the selected options on New Spider would fail contrast",
             'contrast: setup accent text fails on its tint'),
    Mutation("#83a", "the data layer names a network client", "lib/data/app_store.dart",
             sub(r"^library;\n", "library;\n\n// TODO: sync through HttpClient\n", flags=re.M),
             "a network API would enter the layer that holds player data",
             'platform-surface: 1 offender'),
    Mutation("#83b", "the platform channel names a socket", "lib/platform/platform_channel.dart",
             sub(r"^library;\n", "library;\n\n// TODO: WebSocket relay\n", flags=re.M),
             "a network API would enter the app's one bridge to Android",
             'platform-surface: 1 offender'),
    Mutation("#83c", "the channel grows a third method", 
             "android/app/src/main/kotlin/com/honestarcade/solitaire/MainActivity.kt",
             sub(r'(\n(\s*)"openUrl" -> [^\n]*\n)', r'\1\2"upload" -> result.success(true)\n'),
             "a new platform capability would ship unreviewed",
             'platform-surface: the channel handles'),
    Mutation("#83d", "the manifest opts out of Android backup",
             "android/app/src/main/AndroidManifest.xml",
             sub(r"<application\n", '<application\n        android:allowBackup="false"\n'),
             "the player's backup choice would be overridden by the app",
             'platform-surface: the manifest sets android:allowBackup'),
    Mutation("#86", "the release build stops passing the version code",
             ".github/workflows/release.yml",
             sub(r'\n\s*--dart-define=APP_BUILD="\$\{\{ steps\.version\.outputs\.code \}\}"', ''),
             "a store build would show BUILD dev in Settings",
             'release-version: APP_BUILD is not passed'),
    Mutation("#90", "the rules text drifts from the engine's -15",
             "lib/ui/content/rules_text.dart",
             sub(r"\('KlondikeScoring\.standard\.foundationToTableau', -15\)",
                 "('KlondikeScoring.standard.foundationToTableau', -10)"),
             "How to play would state a scoring rule the engine does not play",
             'rules-text: KlondikeScoring.standard.foundationToTableau drifted from the engine'),
    # ---- #96: the bundled fonts (ported from Honest Sudoku's #47) ----------
    Mutation("#96a", "the pubspec declares a weight that is not bundled",
             "pubspec.yaml",
             sub(r"(asset: assets/fonts/Outfit-Bold\.ttf\n\s+weight: )700$",
                 r"\g<1>800", flags=re.M),
             "Flutter would synthesise bold from the wrong face, silently",
             'fonts-declared: 1 offender'),
    Mutation("#96b", "a style asks for a weight Plex Mono does not bundle",
             "lib/ui/fonts.dart",
             sub(r"FontWeight weight = FontWeight\.w500,", "FontWeight weight = FontWeight.w800,"),
             "the engine would fake a heavier weight instead of the design's",
             'fonts-weights: 1 offender'),
    Mutation("#96c", "a font file stops matching its recorded hash",
             "assets/fonts/SHA256SUMS",
             sub(r"^[0-9a-f]{64}(  Outfit-Regular\.ttf)$", "0" * 64 + r"\1",
                 flags=re.M),
             "a swapped font file would ship unnoticed",
             'fonts-check: fetch_fonts.sh --check exited 1', slow=True),
    Mutation("#96d", "a licence text drops out of the provenance record",
             "assets/fonts/SOURCES.tsv",
             sub(r"^OFL-IBMPlexMono\.txt\t[^\n]*\n", "", flags=re.M),
             "the OFL requires the licence to travel with the fonts",
             'fonts-provenance: 1 offender'),
    Mutation("#96e", "a style reaches for Google Fonts at run time",
             "lib/ui/fonts.dart",
             sub(r"const String kFontMono = 'IBM Plex Mono';",
                 "const String kFontMono = 'IBM Plex Mono';\nconst String kFontUrl = 'https://fonts.googleapis.com/css2?family=Outfit';"),
             "a font fetched at run time is the network invariant 1 forbids",
             'fonts-hosts: 1 offender'),
    # ---- #97: the launcher icon and the start screen -----------------------
    Mutation("#97a", "the template's default icon is back at one density",
             "", None,
             "the store build would ship Flutter's placeholder icon again",
             'launcher-template: 1 offender',
             replaces_with=(("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
                             "test/fixtures/template_ic_launcher_xxxhdpi.png"),)),
    Mutation("#97b", "the adaptive icon loses its themed layer",
             "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
             sub(r"\n    <monochrome [^\n]*/>", ""),
             "Android 13 themed icons would show a generic tile",
             'launcher-adaptive: 1 offender'),
    Mutation("#97c", "one source's mark drifts from the others",
             "assets/brand/android-foreground.svg",
             sub(r'd="M 32 14 C 30 18', 'd="M 32 15 C 30 18'),
             "the icon's layers would stop agreeing on the mark",
             'launcher-sources: the inline mark copies differ'),
    Mutation("#97d", "the Android 12 splash loses the mark",
             "android/app/src/main/res/values-v31/styles.xml",
             sub(r'\n\s*<item name="android:windowSplashScreenAnimatedIcon">[^\n]*', ''),
             "the system splash would show the icon Android forces, not the mark",
             'launcher-splash: 1 offender'),
    Mutation("#97e", "a start-screen mark raster goes missing",
             "", None,
             "the pre-12 start screen would fail to inflate its drawable",
             'launcher-rasters: 1 offender',
             deletes="android/app/src/main/res/drawable-xhdpi/launch_mark.png"),
    # ---- #98: the audio assets ---------------------------------------------
    # The file alone cannot go: a declared asset that is missing stops
    # `flutter test` at the asset bundle, which is the wrong reason. The
    # honest shape is the file gone AND its pubspec line tidied away, which
    # is exactly what a "clean-up" commit would do (#98).
    Mutation("#98a", "a clip the app plays goes missing, and its pubspec line with it",
             "pubspec.yaml",
             sub(r"\n    - assets/audio/chime\.wav", ""),
             "the player would hear nothing where the chime belongs",
             'assets/audio/chime.wav: missing',
             deletes="assets/audio/chime.wav"),
    Mutation("#98b", "a clip loses its licence row",
             "assets/audio/LICENSES.md",
             sub(r"^\| `snap\.wav` \|[^\n]*\n", "", flags=re.M),
             "an unrecorded clip could be swapped for anything",
             'audio-assets: 1 offender'),
    Mutation("#98c", "a clip drops out of the bundle",
             "pubspec.yaml",
             sub(r"\n    - assets/audio/flip\.wav", ""),
             "the app would fail to load the flip at run time",
             'audio-declared: 1 offender'),
    # ---- #100: the vector icons ------------------------------------------
    Mutation("#100", "a tool-row icon goes back to a text glyph",
             "lib/ui/game/tool_row.dart",
             sub(r"GlyphIcon\(t\.glyph, size: 15 \* s, color: fg\)",
                 "Text('\u21ba', style: TextStyle(fontSize: 15 * s, color: fg))"),
             "a phone without that glyph in its fonts would show a box",
             'glyph-scan: 1 offender'),
    # ---- #101: the sound bridge --------------------------------------------
    Mutation("#101a", "the sound channel grows a seventh method",
             "android/app/src/main/kotlin/com/honestarcade/solitaire/SoundBridge.kt",
             sub(r'(\n(\s*)"release" -> \{)', r'\n\2"upload" -> result.success(true)\1'),
             "a new platform capability would ship unreviewed",
             'platform-surface: the sound channel handles'),
    Mutation("#101b", "the volume keys stop controlling the media stream",
             "android/app/src/main/kotlin/com/honestarcade/solitaire/MainActivity.kt",
             sub(r"\n\s*volumeControlStream = AudioManager\.STREAM_MUSIC", ""),
             "the volume keys would change the ringer while a game plays",
             'MainActivity.kt: volumeControlStream is not STREAM_MUSIC'),
    Mutation("#101c", "the bridge starts taking audio focus",
             "android/app/src/main/kotlin/com/honestarcade/solitaire/SoundBridge.kt",
             sub(r"(private fun musicStart\(\): Boolean \{\n)", r"\1        // manager?.requestAudioFocus(null, 3, 1)\n"),
             "the loop would duck or stop the player's own music",
             'SoundBridge.kt: requests audio focus'),
    Mutation("#101d", "the bridge stops checking for another app's audio",
             "android/app/src/main/kotlin/com/honestarcade/solitaire/SoundBridge.kt",
             sub(r"if \(manager != null && manager\.isMusicActive\) return false", "if (manager == null) return false"),
             "the loop would play over the player's podcast",
             'SoundBridge.kt: no isMusicActive check'),
    # ---- #102: contrast -----------------------------------------------------
    Mutation("#102", "a dim text token goes back to its design value",
             "lib/ui/theme/palette.dart",
             sub(r"static const textMuted = Color\(0xFF93AACB\);", "static const textMuted = Color(0xFF5C7FB0);"),
             "the loading label would read 2.65:1 on the felt",
             'muted labels: #5C7FB0 on'),
    # ---- #105: route transitions -------------------------------------------
    Mutation("#105", "a screen is pushed with the platform's own transition",
             "lib/ui/navigation.dart",
             sub(r"FadePageRoute<void>\(builder: \(_\) => screen\)", "MaterialPageRoute<void>(builder: (_) => screen)"),
             "Settings would slide up the Android way instead of cross-fading",
             'route-transitions MaterialPageRoute in lib/ui/navigation.dart'),
    # ---- #106: large text ------------------------------------------------------
    Mutation("#106a", "the text-size clamp loses its ceiling",
             "lib/ui/app.dart",
             sub(r"\n\s*maxScaleFactor: 1\.3,", ""),
             "at the phone's largest text size every screen would overflow",
             'large-text-clamp:', slow=True),
    Mutation("#106b", "the board ignores the phone's text size again",
             "lib/ui/app.dart",
             sub(r"child: board,\n", "child: MediaQuery.withNoTextScaling(child: board),\n"),
             "the bars would stay small for a player with large text on",
             'large-text-board:', slow=True),
    Mutation("#106c", "the stock's EMPTY label follows the phone's text size",
             "lib/ui/board/board_view.dart",
             sub(r"\n\s*textScaler: TextScaler\.noScaling, // a slot label \(#106\)", ""),
             "the empty-stock label would grow with the system font size",
             'large-text-fixed:', slow=True),
    # ---- #107: haptics ---------------------------------------------------------
    Mutation("#107", "a stray tick outside the haptics port",
             "lib/ui/game/game_controller.dart",
             chain(sub(r"(import 'dart:async';\n)", r"\1import 'package:flutter/services.dart';\n"),
                   sub(r"(  void undo\(\) \{\n)", r"\1    HapticFeedback.lightImpact();\n")),
             "undo would tick with Haptics off",
             'haptics-scan: HapticFeedback. in lib/ui/game/game_controller.dart'),
    # ---- #108: TalkBack ------------------------------------------------------------
    Mutation("#108a", "an announcement spoken outside the announcer",
             "lib/ui/board/board_view.dart",
             chain(sub(r"(import 'dart:async';\n)", r"\1import 'package:flutter/semantics.dart';\n"),
                   sub(r"(  void finishDeal\(\) \{\n)",
                       r"\1    SemanticsService.sendAnnouncement(View.of(context), 'Dealt', TextDirection.ltr);\n")),
             "the deal would be announced to everyone, screen reader or not",
             'announcer-scan: SemanticsService. in lib/ui/board/board_view.dart'),
    Mutation("#108b", "the face-down column label names its top card",
             "lib/ui/board/board_semantics.dart",
             sub(r"'\$\{capital\(columnName\(column\)\)\}, \$\{plural\(down\.length, 'face-down card'\)\}'",
                 r"'${capital(columnName(column))}, ${plural(down.length, 'face-down card')}, ${down.last.spokenName}'"),
             "TalkBack would read the hidden card's rank and suit",
             'face-down: '),
    # ---- #109: tap targets -------------------------------------------------------
    Mutation("#109", "a menu button's hit area shrinks below 48 dp",
             "lib/ui/screens/menu_screen.dart",
             sub(r"(const Key\('menu-stats'\),\n(?:.*\n){1,3}?\s*minHeight: )kMinTapTarget", r"\g<1>40"),
             "Statistics would be a 40 dp target on the menu",
             'expected tap target size of at least', slow=True),
    # ---- #112: end-to-end suite ------------------------------------------------
    Mutation("#112a", "the end-to-end harness moves into shipped dependencies",
             "pubspec.yaml",
             sub(r"^dependencies:\n", "dependencies:\n  integration_test:\n    sdk: flutter\n", flags=re.M),
             "the SDK test harness would compile into the app",
             'dev-only-sdk integration_test in dependencies'),
    Mutation("#112b", "the bundle scan stops looking for the integration_test plugin",
             "tools/check_aab.sh",
             sub(r'if \[ -n "\$INTEGRATION_SEEN" \]; then\n  exit 5\nfi\n', ""),
             "a release bundle carrying the test harness would pass the scan",
             'bundle-scan: the integration_test plugin shipped unrefused', slow=True),
    # ---- #111: the test plan ------------------------------------------------
    Mutation("#111a", "the sampling table loses its only Vegas run",
             "qa/test-plan.md",
             sub(r"^\| R\d+ \| Klondike \|[^\n]*\| Vegas \|[^\n]*\n", "", flags=re.M),
             "Vegas scoring would never be played on the phone",
             'test-plan: sampling table lacks scoring=Vegas'),
    Mutation("#111b", "the run-record template drops a header field",
             "qa/runs/TEMPLATE.md",
             sub(r"^- Runs: [^\n]*\n", "", flags=re.M),
             "a record would not say which sampling rows it covered",
             'test-plan: TEMPLATE.md lacks the header field "Runs:"'),
    Mutation("#111c", "a run record is committed under the wrong name",
             "", None,
             "the record would be missed by anyone listing a device's runs",
             'test-plan: misnamed run record',
             replaces_with=(("qa/runs/2026-09-29-s26-owner.md",
                             "test/fixtures/qa_run_misnamed.md"),),
             creates=("qa/runs/2026-09-29-s26-owner.md",)),
    Mutation("#111d", "a check loses its expected result",
             "qa/test-plan.md",
             sub(r"(### T001 — [^\n]*\nSteps:\n(?:- [^\n]*\n)+)Expected: [^\n]*\n", r"\1"),
             "the owner would run a check with nothing to compare against",
             'test-plan: T001 has no Expected:'),
    # ---- #116: the accessibility sweep ---------------------------------------
    Mutation("#116a", "an A-check loses its expected result",
             "qa/a11y-sweep.md",
             sub(r"(### A01 — [^\n]*\nSteps:\n(?:- [^\n]*\n)+)Expected: [^\n]*\n", r"\1"),
             "the owner would run a sweep check with nothing to compare against",
             'test-plan: A01 in qa/a11y-sweep.md has no Expected:'),
    Mutation("#116b", "an A-check cites a T-check that does not exist",
             "qa/a11y-sweep.md",
             sub(r"(### A01 — [^\n]*\n(?:[^\n#][^\n]*\n)*?Related: )T601", r"\1T699"),
             "the sweep would point the owner at a check the plan does not hold",
             'test-plan: A01 in qa/a11y-sweep.md cites T699, not a live check'),
    Mutation("#116c", "a Klondike line names a move the deal does not have",
             "qa/a11y-sweep.md",
             sub(r'^(2\. On "Eight of spades, column 6, top card", Actions → "Move to column )4"', r'\g<1>5"', flags=re.M),
             "the owner would be told to choose an action TalkBack does not offer",
             'a11y-sweep: klondike line 2 is not a move from the position before it'),
    Mutation("#116d", "a staged announcement is misquoted",
             "qa/a11y-sweep.md",
             sub(r'"Hint: ace of spades to spades foundation"', '"Hint: ace of spades to the foundation"'),
             "the owner would listen for words the app never says",
             'a11y-sweep: the Klondike staging does not quote what the app says'),
    Mutation("#116e", "the Spider win stops one move short",
             "qa/a11y-sweep.md",
             sub(r"\n\d+\. [^\n]*\n\n(Ends with: the win)", r"\n\n\1"),
             "the owner would be left one move short of the win the check promises",
             'a11y-sweep: spider does not end in a win'),
]


def missing_targets(m: Mutation, binary: list) -> list:
    """The binary targets that should exist and do not: a `replaces_with`
    target named in `creates` is a new file, so its absence is expected."""
    new = {ROOT / made for made in m.creates}
    return [p for p in binary if not p.exists() and p not in new]


def snapshot_bytes(paths: list) -> dict:
    """The current bytes of every path, so a binary mutation can be undone."""
    return {p: p.read_bytes() for p in paths}


def restore_bytes(snapshot: dict) -> None:
    """Puts every snapshotted file back, byte for byte, recreating a deleted
    one (and its directory)."""
    for p, data in snapshot.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)


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
            # CI run (Honest Sudoku's, whose battery this is): a print can be
            # CONDITIONAL. Its `signing_guard_test.dart` printed `... could
            # not be reached` only where the Android SDK was missing, which
            # was true of the battery's job and false on a developer's
            # machine, so `'reached'` was vacuous in CI alone.
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
    # printed is environment-dependent -- Honest Sudoku's
    # `signing_guard_test.dart` printed `could not be reached` only where no
    # Android SDK was installed, which made `'reached'` vacuous in CI and
    # fine locally -- so the audit
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
        edits = [*([(m.path, m.apply)] if m.path else []), *m.also]
        targets = [ROOT / path for path, _ in edits]
        originals = [target.read_text() for target in targets]
        binary = [ROOT / m.deletes] if m.deletes else []
        binary += [ROOT / target for target, _ in m.replaces_with]
        label = f"[{i}/{len(selected)}] {m.issue} {m.name}"
        try:
            mutated = [apply(text) for (_, apply), text in zip(edits, originals)]
        except LookupError as exc:
            broken.append((m, str(exc)))
            print(f"  BROKEN  {label}\n          {exc}")
            continue
        missing = missing_targets(m, binary)
        if missing:
            broken.append((m, f"binary target missing: {missing[0]}"))
            print(f"  BROKEN  {label}\n          {missing[0]} does not exist")
            continue
        fixtures = {ROOT / target: (ROOT / fixture).read_bytes()
                    for target, fixture in m.replaces_with}
        same = [p for p, data in fixtures.items()
                if p.exists() and p.read_bytes() == data]
        if (mutated == originals and not binary) or same:
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
            + "".join(f"  {p.relative_to(ROOT)}\n" for p in binary)
        )
        snapshot = snapshot_bytes([p for p in binary if p.exists()])
        for target, text in zip(targets, mutated):
            target.write_text(text)
        if m.deletes:
            (ROOT / m.deletes).unlink()
        for target, data in fixtures.items():
            target.write_bytes(data)
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
            restore_bytes(snapshot)
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
