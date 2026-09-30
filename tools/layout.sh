#!/usr/bin/env bash
# The on-device layout sweep (#114): integration_test/layout_sweep_test.dart
# at the device's default font scale (1.0) and at its largest, with Large
# cards off and on inside each run. Screenshots land in
# build/layout/<date>-<device>[-n]/<font>/, and the log beside them. The
# device's font scale is put back as it was.
#
# Usage:  tools/layout.sh [--avd solitaire-api24|solitaire-dev] [--largest <scale>]
#         tools/layout.sh --device <serial> --yes-wipe [--largest <scale>]
# Default: --avd solitaire-api24 (the smallest supported screen), largest 1.3
# (Android 7.0's largest font size; the app clamps anything above 1.3 to 1.3).
#
# Exit:   0  both runs passed
#         1  a run failed: an overflow, a disallowed ellipsis, or a crash
#         2  bad arguments
#         3  no device, or a physical phone named without --yes-wipe
set -uo pipefail

usage() {
  echo "usage: tools/layout.sh [--avd <name> | --device <serial> --yes-wipe] [--largest <scale>]" >&2
  exit 2
}

AVD=""
SERIAL=""
WIPE=""
LARGEST="1.3"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --avd) [ "$#" -ge 2 ] || usage; AVD="$2"; shift ;;
    --device) [ "$#" -ge 2 ] || usage; SERIAL="$2"; shift ;;
    --yes-wipe) WIPE=1 ;;
    --largest) [ "$#" -ge 2 ] || usage; LARGEST="$2"; shift ;;
    *) usage ;;
  esac
  shift
done
[ -n "$AVD" ] && [ -n "$SERIAL" ] && usage
[ -z "$AVD" ] && [ -z "$SERIAL" ] && AVD="solitaire-api24"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
[ -x "$ADB" ] || { echo "layout: missing $ADB" >&2; exit 3; }

if [ -n "$AVD" ]; then
  SERIAL="$(tools/avd.sh "$AVD")" || { echo "layout: $AVD did not boot" >&2; exit 3; }
fi
[ "$("$ADB" -s "$SERIAL" get-state 2>/dev/null | tr -d '\r')" = "device" ] ||
  { echo "layout: $SERIAL is not attached" >&2; exit 3; }
if [ "$("$ADB" -s "$SERIAL" shell getprop ro.kernel.qemu | tr -d '\r')" = "1" ]; then
  case "$AVD" in
    solitaire-dev) SLUG="emu-dev" ;;
    *) SLUG="emu-api24" ;;
  esac
else
  [ -n "$WIPE" ] || { echo "layout: $SERIAL is a physical device; the run replaces the app and its saves. Pass --yes-wipe to allow it." >&2; exit 3; }
  SLUG="s26ultra"
fi

base="build/layout/$(date +%F)-$SLUG"
OUT="$base"
n=2
while [ -e "$OUT" ]; do OUT="$base-$n"; n=$((n + 1)); done
mkdir -p "$OUT"
LOG="$OUT/layout.log"

before="$("$ADB" -s "$SERIAL" shell settings get system font_scale | tr -d '\r')"
[ "$before" = "null" ] && before="1.0" # never set on this device
# shellcheck disable=SC2329  # invoked by the trap
restore() { "$ADB" -s "$SERIAL" shell settings put system font_scale "${before:-1.0}" >/dev/null 2>&1; }
trap restore EXIT

status=0
for font in 1.0 "$LARGEST"; do
  echo "layout: font scale $font on $SERIAL" | tee -a "$LOG"
  "$ADB" -s "$SERIAL" shell settings put system font_scale "$font"
  "$ADB" -s "$SERIAL" uninstall com.honestarcade.solitaire >>"$LOG" 2>&1 || true
  if LAYOUT_OUT="$OUT/$font" flutter drive -d "$SERIAL" \
    --driver test_driver/screenshot_driver.dart \
    --target integration_test/layout_sweep_test.dart \
    --dart-define=LAYOUT_FONT="$font" >>"$LOG" 2>&1; then
    rm -f "$OUT/$font/discard.png"
    echo "layout: font $font passed ($(find "$OUT/$font" -name '*.png' | wc -l | tr -d ' ') screenshots)" | tee -a "$LOG"
  else
    rm -f "$OUT/$font/discard.png"
    echo "layout: font $font FAILED (log: $LOG)" | tee -a "$LOG"
    status=1
  fi
done
echo "layout: $OUT"
[ "$status" -eq 0 ] && echo "PASSED"
exit "$status"
