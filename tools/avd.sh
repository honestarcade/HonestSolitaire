#!/usr/bin/env bash
# Create (if missing) and boot one of the project's two emulators, then print
# its adb serial on stdout. Idempotent: an AVD that exists is reused, and an
# emulator already running that AVD is reused and left running.
#
#   solitaire-dev    Pixel 7 profile, API 34 — the everyday device (#112, #117)
#   solitaire-api24  API 24 (Android 7.0), 640x1136 px at 320 dpi (320x568 dp,
#                    the smallest supported width), 2 GB RAM — the oldest and
#                    smallest the app claims (#114)
#
# Usage:  tools/avd.sh [--recreate] <solitaire-dev|solitaire-api24>
# Exit:   0  booted; the serial (e.g. emulator-5556) is the only stdout line
#         2  bad arguments
#         3  a tool is missing: the Android SDK, its emulator, cmdline-tools
#            or a Java runtime for them
#         4  creating the AVD or installing its system image failed
#         5  the emulator did not finish booting in time
#
# The emulators are emulators, not hardware: every record made on one says so.
set -euo pipefail

usage() {
  echo "usage: tools/avd.sh [--recreate] <solitaire-dev|solitaire-api24>" >&2
  exit 2
}

RECREATE=""
NAME=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --recreate) RECREATE=1 ;;
    solitaire-dev | solitaire-api24) NAME="$1" ;;
    *) usage ;;
  esac
  shift
done
[ -n "$NAME" ] || usage

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
EMULATOR="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager"
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
for tool in "$EMULATOR" "$ADB" "$AVDMANAGER" "$SDKMANAGER"; do
  [ -x "$tool" ] || { echo "avd: missing $tool" >&2; exit 3; }
done

# sdkmanager and avdmanager need a JVM; macOS ships only a stub.
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
  JAVA_HOME=""
  for candidate in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    /opt/homebrew/opt/openjdk@21 /opt/homebrew/opt/openjdk@17 /opt/homebrew/opt/openjdk; do
    if [ -x "$candidate/bin/java" ]; then JAVA_HOME="$candidate"; break; fi
  done
  if [ -z "$JAVA_HOME" ] && /usr/libexec/java_home >/dev/null 2>&1; then
    JAVA_HOME="$(/usr/libexec/java_home)"
  fi
  [ -n "$JAVA_HOME" ] || { echo "avd: no Java runtime for the SDK tools (set JAVA_HOME)" >&2; exit 3; }
fi
export JAVA_HOME

case "$NAME" in
  solitaire-dev) IMAGE="system-images;android-34;google_apis;arm64-v8a" DEVICE="pixel_7" ;;
  solitaire-api24) IMAGE="system-images;android-24;google_apis;arm64-v8a" DEVICE="Nexus S" ;;
esac

# The serial of a running emulator whose AVD is $NAME, if any.
running_serial() {
  "$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/ {print $1}' |
    while read -r serial; do
      avd="$("$ADB" -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
      if [ "$avd" = "$NAME" ]; then echo "$serial"; break; fi
    done
}

AVD_DIR="$HOME/.android/avd/$NAME.avd"
if [ -n "$RECREATE" ]; then
  if [ -n "$(running_serial)" ]; then
    echo "avd: $NAME is running; stop it before --recreate" >&2
    exit 4
  fi
  "$AVDMANAGER" delete avd -n "$NAME" >/dev/null 2>&1 || true
fi

if [ ! -d "$AVD_DIR" ]; then
  image_dir="$SDK/$(printf '%s' "$IMAGE" | tr ';' '/')"
  if [ ! -d "$image_dir" ]; then
    echo "avd: installing $IMAGE" >&2
    # Not `yes | sdkmanager`: under pipefail, yes dies of SIGPIPE when the
    # licence prompts end, and the pipeline reports that as a failure.
    "$SDKMANAGER" --install "$IMAGE" < <(yes) >&2 || true
    [ -f "$image_dir/system.img" ] || { echo "avd: could not install $IMAGE" >&2; exit 4; }
  fi
  echo "no" | "$AVDMANAGER" create avd -n "$NAME" -k "$IMAGE" -d "$DEVICE" --force >&2 ||
    { echo "avd: could not create $NAME" >&2; exit 4; }
  config="$AVD_DIR/config.ini"
  {
    echo "hw.gpu.enabled=yes"
    echo "hw.gpu.mode=host"
    echo "hw.keyboard=no"
    echo "hw.mainKeys=no"
    echo "showDeviceFrame=no"
    if [ "$NAME" = "solitaire-api24" ]; then
      echo "hw.lcd.width=640"
      echo "hw.lcd.height=1136"
      echo "hw.lcd.density=320"
      echo "hw.ramSize=2048"
    fi
  } >> "$config"
fi

SERIAL="$(running_serial)"
if [ -z "$SERIAL" ]; then
  before="$("$ADB" devices | awk '/^emulator-/ {print $1}' | sort)"
  # Cold boot, no snapshot: every run starts from the same state.
  nohup "$EMULATOR" -avd "$NAME" -no-snapshot -no-boot-anim -no-audio -no-window \
    -gpu host >"${TMPDIR:-/tmp}/avd-$NAME.log" 2>&1 &
  for _ in $(seq 1 90); do
    sleep 2
    after="$("$ADB" devices | awk '/^emulator-/ {print $1}' | sort)"
    SERIAL="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -1)"
    [ -n "$SERIAL" ] && break
  done
  [ -n "$SERIAL" ] || { echo "avd: $NAME never appeared in adb (log: ${TMPDIR:-/tmp}/avd-$NAME.log)" >&2; exit 5; }
fi

for _ in $(seq 1 150); do
  if [ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
    echo "$SERIAL"
    exit 0
  fi
  sleep 2
done
echo "avd: $NAME ($SERIAL) did not finish booting in 300 s" >&2
exit 5
