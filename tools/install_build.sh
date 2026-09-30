#!/usr/bin/env bash
# Install a released internal build on an emulator or device (#114): the
# release's app-release.aab, verified against its .sha256, turned into APKs
# for the device by bundletool and installed. The APKs are signed with the
# local debug key, so the install replaces any Play build (and its saves).
#
# Usage:  tools/install_build.sh <tag> [--avd <name> | --device <serial>]
# Default: --avd solitaire-dev (booted by tools/avd.sh).
#
# Exit:   0  installed
#         2  bad arguments, or no device
#         3  a tool is missing: adb, gh, a Java runtime, keytool
#         4  the download or a checksum (bundle or bundletool) failed
#         5  bundletool or the install failed
set -uo pipefail

usage() {
  echo "usage: tools/install_build.sh <tag> [--avd <name> | --device <serial>]" >&2
  exit 2
}

TAG=""
AVD=""
SERIAL=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --avd) [ "$#" -ge 2 ] || usage; AVD="$2"; shift ;;
    --device) [ "$#" -ge 2 ] || usage; SERIAL="$2"; shift ;;
    -*) usage ;;
    *) [ -z "$TAG" ] || usage; TAG="$1" ;;
  esac
  shift
done
[ -n "$TAG" ] || usage
[ -n "$AVD" ] && [ -n "$SERIAL" ] && usage
[ -z "$AVD" ] && [ -z "$SERIAL" ] && AVD="solitaire-dev"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
[ -x "$ADB" ] || { echo "install: missing $ADB" >&2; exit 3; }
command -v gh >/dev/null || { echo "install: missing gh" >&2; exit 3; }

if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
  JAVA_HOME=""
  for candidate in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    /opt/homebrew/opt/openjdk@21 /opt/homebrew/opt/openjdk@17 /opt/homebrew/opt/openjdk; do
    if [ -x "$candidate/bin/java" ]; then JAVA_HOME="$candidate"; break; fi
  done
  [ -n "$JAVA_HOME" ] || { echo "install: no Java runtime (set JAVA_HOME)" >&2; exit 3; }
fi
JAVA="$JAVA_HOME/bin/java"
KEYTOOL="$JAVA_HOME/bin/keytool"

sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }

# bundletool, pinned by version and hash.
BT_VERSION="$(awk -F= '/^version=/ {print $2}' tools/bundletool.version)"
BT_SHA="$(awk -F= '/^sha256=/ {print $2}' tools/bundletool.version)"
[ -n "$BT_VERSION" ] && [ -n "$BT_SHA" ] || { echo "install: tools/bundletool.version is incomplete" >&2; exit 4; }
BT="build/tools/bundletool-all-$BT_VERSION.jar"
mkdir -p build/tools
if [ ! -f "$BT" ]; then
  curl -sSfL -o "$BT" \
    "https://github.com/google/bundletool/releases/download/$BT_VERSION/bundletool-all-$BT_VERSION.jar" ||
    { rm -f "$BT"; echo "install: could not download bundletool $BT_VERSION" >&2; exit 4; }
fi
[ "$(sha256 "$BT")" = "$BT_SHA" ] ||
  { rm -f "$BT"; echo "install: bundletool $BT_VERSION does not match its pinned sha256" >&2; exit 4; }

# The bundle, checked against the sidecar the release workflow wrote.
WORK="build/install/$TAG"
rm -rf "$WORK"
mkdir -p "$WORK"
gh release download "$TAG" --pattern 'app-release.aab' --pattern 'app-release.aab.sha256' --dir "$WORK" ||
  { echo "install: could not download $TAG's bundle and checksum" >&2; exit 4; }
want="$(awk '{print $1; exit}' "$WORK/app-release.aab.sha256")"
[ -n "$want" ] && [ "$(sha256 "$WORK/app-release.aab")" = "$want" ] ||
  { echo "install: $TAG's bundle does not match its .sha256" >&2; exit 4; }

# The device.
if [ -n "$AVD" ]; then
  SERIAL="$(tools/avd.sh "$AVD")" || { echo "install: $AVD did not boot" >&2; exit 2; }
fi
[ "$("$ADB" -s "$SERIAL" get-state 2>/dev/null | tr -d '\r')" = "device" ] ||
  { echo "install: $SERIAL is not attached" >&2; exit 2; }

# The debug key, made with Android's default passwords when absent.
KEYSTORE="$HOME/.android/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  [ -x "$KEYTOOL" ] || { echo "install: missing $KEYTOOL" >&2; exit 3; }
  mkdir -p "$HOME/.android"
  "$KEYTOOL" -genkeypair -keystore "$KEYSTORE" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 ||
    { echo "install: could not create $KEYSTORE" >&2; exit 3; }
fi

"$JAVA" -jar "$BT" build-apks --bundle="$WORK/app-release.aab" --output="$WORK/app.apks" \
  --connected-device --device-id="$SERIAL" --adb="$ADB" \
  --ks="$KEYSTORE" --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android ||
  { echo "install: bundletool build-apks failed" >&2; exit 5; }
# A Play build signed with another key cannot be replaced in place.
"$ADB" -s "$SERIAL" uninstall com.honestarcade.solitaire >/dev/null 2>&1 || true
"$JAVA" -jar "$BT" install-apks --apks="$WORK/app.apks" --device-id="$SERIAL" --adb="$ADB" ||
  { echo "install: bundletool install-apks failed" >&2; exit 5; }
echo "installed $TAG on $SERIAL"
