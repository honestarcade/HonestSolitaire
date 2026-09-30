#!/usr/bin/env bash
# The on-device end-to-end suite (#112): every integration_test/*_game_test.dart,
# each in two phases with a real force-stop between
# them. Phase 1 plays, backgrounds the app through the lifecycle channel and
# prints E2E_PHASE1_DONE; the script then kills the app, and phase 2 cold
# starts it and continues the saved game to the win.
#
# Usage:  tools/e2e.sh [--avd solitaire-dev|solitaire-api24]
#         tools/e2e.sh --device <serial> [--yes-wipe]
# Default: --avd solitaire-dev (booted by tools/avd.sh, reused if running).
#
# Every test file starts from a clean install: the app and all its data are
# uninstalled first. A physical phone is refused unless --yes-wipe is given,
# so the owner's saved games and statistics are never wiped by accident.
#
# Exit:   0  every phase passed (the last line is PASSED)
#         2  bad arguments
#         3  no device: the AVD did not boot, the serial is not attached, or
#            a physical phone was named without --yes-wipe
#         4  a phase 1 failed (or never printed E2E_PHASE1_DONE)
#         5  a phase 2 failed
#
# Runs are debug builds: `flutter test` on a device builds nothing else.
# Timing is #117's job (tools/perf.sh), not this suite's.
set -uo pipefail

usage() {
  echo "usage: tools/e2e.sh [--avd <name> | --device <serial> [--yes-wipe]]" >&2
  exit 2
}

AVD=""
SERIAL=""
WIPE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --avd) [ "$#" -ge 2 ] || usage; AVD="$2"; shift ;;
    --device) [ "$#" -ge 2 ] || usage; SERIAL="$2"; shift ;;
    --yes-wipe) WIPE=1 ;;
    *) usage ;;
  esac
  shift
done
[ -n "$AVD" ] && [ -n "$SERIAL" ] && usage
[ -z "$AVD" ] && [ -z "$SERIAL" ] && AVD="solitaire-dev"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
[ -x "$ADB" ] || { echo "e2e: missing $ADB" >&2; exit 3; }
PACKAGE="com.honestarcade.solitaire"

mkdir -p build/e2e
n=1
while [ -e "build/e2e/$(date +%F)-$n.log" ]; do n=$((n + 1)); done
LOG="build/e2e/$(date +%F)-$n.log"
say() { echo "$*" | tee -a "$LOG"; }

if [ -n "$AVD" ]; then
  SERIAL="$(tools/avd.sh "$AVD" 2>>"$LOG")" || { say "e2e: $AVD did not boot (see $LOG)"; exit 3; }
fi
state="$("$ADB" -s "$SERIAL" get-state 2>/dev/null | tr -d '\r')"
[ "$state" = "device" ] || { say "e2e: $SERIAL is not attached"; exit 3; }
emulator="$("$ADB" -s "$SERIAL" shell getprop ro.kernel.qemu 2>/dev/null | tr -d '\r')"
if [ "$emulator" != "1" ] && [ -z "$WIPE" ]; then
  say "e2e: $SERIAL is a physical device; the run uninstalls the app and its saves. Pass --yes-wipe to allow it."
  exit 3
fi

say "e2e: $(date '+%F %T') on $SERIAL ($("$ADB" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r'), Android $("$ADB" -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r'))"
say "e2e: commit $(git rev-parse --short HEAD)$([ -z "$(git status --porcelain)" ] || echo ' (with uncommitted changes)')"

run_phase() { # file phase extra-define...
  local file="$1" phase="$2"
  shift 2
  say "e2e: $file phase $phase"
  flutter test "$file" -d "$SERIAL" --no-uninstall --timeout 10m \
    --dart-define=E2E_PHASE="$phase" "$@" >>"$LOG" 2>&1
}

for file in integration_test/*_game_test.dart; do
  say "e2e: uninstalling $PACKAGE"
  "$ADB" -s "$SERIAL" uninstall "$PACKAGE" >>"$LOG" 2>&1 || true

  mark=$(wc -l <"$LOG")
  if ! run_phase "$file" 1; then
    say "e2e: FAILED $file phase 1 (log: $LOG)"
    exit 4
  fi
  line="$(tail -n +"$((mark + 1))" "$LOG" | grep -o 'E2E_PHASE1_DONE E2E_ELAPSED_MS=[0-9]*' | tail -1)"
  if [ -z "$line" ]; then
    say "e2e: FAILED $file phase 1 never reached E2E_PHASE1_DONE (log: $LOG)"
    exit 4
  fi
  elapsed="${line##*=}"

  say "e2e: force-stopping $PACKAGE"
  "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE" >>"$LOG" 2>&1

  if ! run_phase "$file" 2 --dart-define=E2E_ELAPSED_MS="$elapsed"; then
    say "e2e: FAILED $file phase 2 (log: $LOG)"
    exit 5
  fi
done

say "e2e: log $LOG"
say "PASSED"
