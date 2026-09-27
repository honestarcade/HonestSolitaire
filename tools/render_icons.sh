#!/usr/bin/env bash
# Renders the launcher icons, the start-screen mark and the Play Store icon
# from assets/brand/ (#97; from Honest Sudoku's script without its font check,
# because this icon has no text).
#
# The outputs are committed; CI never runs this.
#
#   tools/render_icons.sh [OUTPUT_ROOT]   render (default: the repo's paths)
#   tools/render_icons.sh --check         render into build/icon-check/ and
#                                         list byte differences (exit 0)
#
# Exit: 0 rendered, 3 a tool is missing, 5 an output's pixel size is wrong.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

for tool in rsvg-convert python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "render_icons: $tool is missing (brew install librsvg)" >&2
    exit 3
  fi
done

CHECK=0
OUT="$ROOT"
if [ "${1:-}" = "--check" ]; then
  CHECK=1
  OUT="$ROOT/build/icon-check"
  rm -rf "$OUT"
elif [ -n "${1:-}" ]; then
  OUT="$1"
fi

render() { # source size output
  mkdir -p "$(dirname "$OUT/$3")"
  rsvg-convert -w "$2" -h "$2" "assets/brand/$1" -o "$OUT/$3"
  python3 - "$OUT/$3" "$2" <<'PY' || exit 5
import struct, sys
data = open(sys.argv[1], "rb").read(24)
w, h = struct.unpack(">II", data[16:24])
want = int(sys.argv[2])
if data[:8] != b"\x89PNG\r\n\x1a\n" or (w, h) != (want, want):
    sys.exit(f"render_icons: {sys.argv[1]} is {w}x{h}, not {want}x{want}")
PY
  echo "  $3 (${2}px)"
}

res=android/app/src/main/res
for pair in mdpi:108:48:96 hdpi:162:72:144 xhdpi:216:96:192 xxhdpi:324:144:288 xxxhdpi:432:192:384; do
  IFS=: read -r density layer legacy mark <<<"$pair"
  render android-foreground.svg "$layer" "$res/mipmap-$density/ic_launcher_foreground.png"
  render android-monochrome.svg "$layer" "$res/mipmap-$density/ic_launcher_monochrome.png"
  render icon-legacy.svg "$legacy" "$res/mipmap-$density/ic_launcher.png"
  # The pre-12 start screen's mark: the foreground at 96 dp, whole bitmap.
  render android-foreground.svg "$mark" "$res/drawable-$density/launch_mark.png"
done
render icon-tile.svg 512 ArtSource/store/icon-512.png
# Play wants a 32-bit PNG for the store icon, and rsvg-convert writes an
# opaque image as 24-bit RGB; add the (all-opaque) alpha channel.
python3 - "$OUT/ArtSource/store/icon-512.png" <<'PY' || exit 5
import struct, sys, zlib
path = sys.argv[1]
data = open(path, "rb").read()
chunks, at = [], 8
while at < len(data):
    n, kind = struct.unpack(">I4s", data[at:at + 8])
    chunks.append((kind, data[at + 8:at + 8 + n]))
    at += 12 + n
ihdr = dict(chunks)[b"IHDR"]
w, h, depth, ctype = struct.unpack(">IIBB", ihdr[:10])
if ctype == 6:
    sys.exit(0)
if (depth, ctype) != (8, 2):
    sys.exit(f"render_icons: {path} is depth {depth} type {ctype}")
raw = zlib.decompress(b"".join(c for k, c in chunks if k == b"IDAT"))
stride, bpp, prev, out = w * 3, 3, bytearray(w * 3), bytearray()
for y in range(h):
    f, row = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
    for x in range(stride):
        a = row[x - bpp] if x >= bpp else 0
        b = prev[x]
        c = prev[x - bpp] if x >= bpp else 0
        if f == 1: row[x] = (row[x] + a) & 255
        elif f == 2: row[x] = (row[x] + b) & 255
        elif f == 3: row[x] = (row[x] + (a + b) // 2) & 255
        elif f == 4:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            row[x] = (row[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
    out += b"\x00" + b"".join(bytes(row[i:i + 3]) + b"\xff" for i in range(0, stride, 3))
    prev = row
def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(bytes(out), 9)) + chunk(b"IEND", b""))
open(path, "wb").write(png)
PY

if [ "$CHECK" -eq 1 ]; then
  (cd "$OUT" && find . -name '*.png' | sort) | while read -r f; do
    cmp -s "$OUT/$f" "$ROOT/$f" || echo "differs: ${f#./}"
  done
fi
echo "render_icons: done"
