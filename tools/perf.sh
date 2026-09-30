#!/usr/bin/env bash
# The on-device measurement (#117): integration_test/perf_test.dart in
# profile mode through flutter drive. It checks every golden deal against the
# host's pins, then times the winnable search for each Klondike draw mode, and
# writes qa/perf/<date>-<device>[-n].md with its .json beside it (the raw
# report, also in build/perf/ with the drive's log).
#
# Usage:  tools/perf.sh [--avd solitaire-dev|solitaire-api24] [--searches N] [--no-idle]
#         tools/perf.sh --device <serial> --yes-wipe [--searches N] [--no-idle]
# Default: --avd solitaire-dev, 100 searches per draw mode, 2 min idle first.
#
# A profile build is signed with the debug key, so installing it replaces a
# Play build and deletes its saves: a physical phone is refused without
# --yes-wipe.
#
# Exit:   0  the report was written and every golden deal matched (the
#            95 % target is reported in the .md, not enforced here)
#         1  a golden deal differed on the device, or a tool failed
#         2  bad arguments
#         3  no device, or a physical phone named without --yes-wipe
set -uo pipefail

usage() {
  echo "usage: tools/perf.sh [--avd <name> | --device <serial> --yes-wipe] [--searches N] [--no-idle]" >&2
  exit 2
}

AVD=""
SERIAL=""
WIPE=""
SEARCHES=100
IDLE=120
while [ "$#" -gt 0 ]; do
  case "$1" in
    --avd) [ "$#" -ge 2 ] || usage; AVD="$2"; shift ;;
    --device) [ "$#" -ge 2 ] || usage; SERIAL="$2"; shift ;;
    --yes-wipe) WIPE=1 ;;
    --searches) [ "$#" -ge 2 ] || usage; SEARCHES="$2"; shift ;;
    --no-idle) IDLE=0 ;;
    *) usage ;;
  esac
  shift
done
[ -n "$AVD" ] && [ -n "$SERIAL" ] && usage
[ -z "$AVD" ] && [ -z "$SERIAL" ] && AVD="solitaire-dev"
case "$SEARCHES" in '' | *[!0-9]*) usage ;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
[ -x "$ADB" ] || { echo "perf: missing $ADB" >&2; exit 3; }

if [ -n "$AVD" ]; then
  SERIAL="$(tools/avd.sh "$AVD")" || { echo "perf: $AVD did not boot" >&2; exit 3; }
fi
[ "$("$ADB" -s "$SERIAL" get-state 2>/dev/null | tr -d '\r')" = "device" ] ||
  { echo "perf: $SERIAL is not attached" >&2; exit 3; }
prop() { "$ADB" -s "$SERIAL" shell getprop "$1" 2>/dev/null | tr -d '\r'; }
if [ "$(prop ro.kernel.qemu)" = "1" ]; then
  KIND="emulator ($(prop ro.boot.qemu.avd_name))"
  case "$AVD" in
    solitaire-api24) SLUG="emu-api24" ;;
    *) SLUG="emu-dev" ;;
  esac
else
  [ -n "$WIPE" ] || {
    echo "perf: $SERIAL is a physical device; installing a profile build deletes the app's saves. Pass --yes-wipe to allow it." >&2
    exit 3
  }
  KIND="hardware"
  SLUG="s26ultra"
fi

mkdir -p build/perf qa/perf
base="$(date +%F)-$SLUG"
name="$base"
n=2
while [ -e "qa/perf/$name.md" ]; do name="$base-$n"; n=$((n + 1)); done
JSON="build/perf/$name.json"
MD="qa/perf/$name.md"
LOG="build/perf/$name.log"

if [ "$IDLE" -gt 0 ]; then
  echo "perf: idling ${IDLE}s so the device settles" | tee -a "$LOG"
  sleep "$IDLE"
fi
battery="$("$ADB" -s "$SERIAL" shell dumpsys battery 2>/dev/null | tr -d '\r')"
level="$(printf '%s\n' "$battery" | awk -F': ' '/ level:/ {print $2; exit}')"
powered="$(printf '%s\n' "$battery" | awk -F': ' '/(AC|USB|Wireless) powered: true/ {print "yes"; exit}')"
oneui="$(prop ro.build.version.oneui)"

# Read before the build, so a commit made during the run is not credited.
BUILD="profile build of $(git rev-parse --short HEAD)$([ -z "$(git status --porcelain)" ] || echo ' with uncommitted changes')"
echo "perf: flutter drive --profile on $SERIAL, $SEARCHES searches per draw mode" | tee -a "$LOG"
PERF_OUT="$JSON" flutter drive --profile -d "$SERIAL" \
  --driver test_driver/perf_driver.dart --target integration_test/perf_test.dart \
  --dart-define=PERF_SEARCHES="$SEARCHES" >>"$LOG" 2>&1
drive_rc=$?
[ -s "$JSON" ] || { echo "perf: no report from the device (flutter drive rc=$drive_rc, log: $LOG)" >&2; exit 1; }

python3 tools/perf_report.py "$JSON" "$MD" \
  "Device=$(prop ro.product.manufacturer) $(prop ro.product.model)" \
  "Android=$(prop ro.build.version.release) (API $(prop ro.build.version.sdk))${oneui:+, One UI $oneui}" \
  "Hardware or emulator=$KIND" \
  "Build=$BUILD" \
  "Flutter=$(flutter --version 2>/dev/null | head -1)" \
  "Battery=${level:-?} %, charging: ${powered:-no}" \
  "Date=$(date '+%F %T %Z')"
report_rc=$?
cp "$JSON" "qa/perf/$name.json"
echo "perf: $MD (json: qa/perf/$name.json, log: $LOG)"
if [ "$report_rc" -ne 0 ] || [ "$drive_rc" -ne 0 ]; then
  echo "perf: FAILED (drive rc=$drive_rc, report rc=$report_rc)" >&2
  exit 1
fi
echo "PASSED"
