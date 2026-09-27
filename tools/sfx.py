#!/usr/bin/env python3
"""Sound generation (#98): ElevenLabs text-to-sound-effects into the game's
five clip names, post-processed to the lengths and levels the game expects.

Ported from Honest Sudoku's tools/sfx.py (its #49) with Honest Frog Across's
loop path and relevel added back. It is NOT reproducible -- the model returns
something new on every call -- so the committed WAVs are the artifacts of
record. One clip per prompt, no auditioning (owner, /n8-plan M5 round one).
It is never run by CI and needs the owner's key.

Usage:
  python3 tools/sfx.py generate [--only deal,flip] [--force] [--dry-run]
  python3 tools/sfx.py relevel            # set the installed loop to MUSIC_DBFS

The key comes from ELEVENLABS_API_KEY, or the script loads
~/HonestArcadeApps/secrets/elevenlabs.env itself (KEY=value lines, `export`
and quotes tolerated). Clips stage in build/sfx/ and install into
assets/audio/ (an existing clip needs --force); PROMPTS.md and the LICENSES.md
rows are written alongside. Standard library only; certifi is used for the CA
bundle when it is installed.
"""
import argparse
import datetime
import json
import os
import re
import ssl
import struct
import sys
import time
import urllib.error
import urllib.request
import wave
from pathlib import Path

API = "https://api.elevenlabs.io/v1/sound-generation?output_format=pcm_44100"
ENDPOINT = "POST /v1/sound-generation"
MODEL = "eleven_text_to_sound_v2"
PLAN = "Creator"
RATE = 44100
# pcm_44100 comes back as INTERLEAVED STEREO 16-bit (Frog Across found this
# against `afinfo` on 2026-09-16); everything is written mono.
CHANNELS = 2
ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "assets" / "audio"
STAGE = ROOT / "build" / "sfx"
LICENSES = DEST / "LICENSES.md"
PROMPTS = DEST / "PROMPTS.md"
ENV_FILE = Path.home() / "HonestArcadeApps" / "secrets" / "elevenlabs.env"
TIMEOUT = 60
RETRIES = 1

# clip -> (prompt, target_seconds). Written in the Frog Across style: dry,
# short, and "no music" on the effects.
SOUNDS = {
    "deal": ("a quick soft riffle of playing cards being dealt onto a felt "
             "table, short, dry, close, no music", 0.45),
    "flip": ("a single playing card flipping over on felt, a short crisp "
             "paper snap, dry, no music", 0.18),
    "snap": ("a soft muted tap of a playing card landing in place on felt, "
             "very short, dry, no music", 0.12),
    "chime": ("a bright warm three-note ascending chime, short, clean, "
              "rewarding, no music", 0.90),
}

# The one loop, from the sound-effects endpoint's loop flag (v2 model) rather
# than Eleven Music: the SFX terms grant a plain commercial licence on any
# paid plan. An ambient bed, not a composed soundtrack.
MUSIC = {
    "music": ("a calm unobtrusive card-table background bed, soft warm piano "
              "and a gentle pad, slow and steady, instrumental, no drums, "
              "seamless loop", 30.0),
}

# Relative level per effect, in dB below full scale, applied after polish
# normalises to -1 dBFS, so a snap heard on every move does not match the
# chime for loudness.
MIX_DB = {
    "snap": -6.0,
    "flip": -6.0,
    "deal": -4.0,
    "chime": -3.0,
}

# Absolute peak the loop sits at once installed: declared absolutely so
# re-levelling is idempotent (Frog Across #120).
MUSIC_DBFS = {
    "music": -15.0,
}


def _peak(pcm: bytes) -> int:
    """Largest absolute 16-bit sample."""
    hi = 0
    for i in range(0, len(pcm) - 1, 2):
        v = struct.unpack_from("<h", pcm, i)[0]
        if v == -32768:
            return 32768
        hi = max(hi, abs(v))
    return hi


def _scale(pcm: bytes, factor: float) -> bytes:
    """Multiply every sample, clamped to the 16-bit range."""
    out = bytearray(len(pcm))
    for i in range(0, len(pcm) - 1, 2):
        v = int(struct.unpack_from("<h", pcm, i)[0] * factor)
        struct.pack_into("<h", out, i, max(-32768, min(32767, v)))
    return bytes(out)


def _to_mono(pcm: bytes) -> bytes:
    """Average interleaved stereo down to mono."""
    out = bytearray(len(pcm) // 2)
    for i in range(0, len(pcm) - 3, 4):
        left = struct.unpack_from("<h", pcm, i)[0]
        right = struct.unpack_from("<h", pcm, i + 2)[0]
        struct.pack_into("<h", out, i // 2, (left + right) // 2)
    return bytes(out)


def polish(pcm: bytes, seconds: float) -> bytes:
    """Trim the silent head, cut to length, fade out, normalise to -1 dBFS.

    Leading silence is the one defect a player feels rather than hears: on
    the snap it reads as input lag.
    """
    if not pcm:
        return pcm
    pcm = _to_mono(pcm)
    peak = _peak(pcm) or 1
    gate = max(int(peak * 0.02), 64)

    start = 0
    for i in range(0, len(pcm) - 1, 2):
        if abs(struct.unpack_from("<h", pcm, i)[0]) > gate:
            start = i
            break
    start = max(0, start - int(0.005 * RATE) * 2)  # 5ms of pre-roll
    pcm = pcm[start:]

    want = int(seconds * RATE) * 2
    if len(pcm) > want:
        pcm = pcm[:want]

    # 12ms fade-out so a hard cut never clicks
    fade = min(int(0.012 * RATE), len(pcm) // 4)
    if fade > 0:
        tail = bytearray(pcm[-fade * 2:])
        for n in range(fade):
            off = n * 2
            v = struct.unpack_from("<h", tail, off)[0]
            struct.pack_into("<h", tail, off, int(v * (1 - n / fade)))
        pcm = pcm[:-fade * 2] + bytes(tail)

    peak = _peak(pcm) or 1
    return _scale(pcm, min(8.0, (32767 * 0.89) / peak))  # -1 dBFS


def polish_loop(pcm: bytes, dbfs: float) -> bytes:
    """A loop may not be trimmed or faded -- either would break the seam.
    Mono, and the level set once, absolutely."""
    pcm = _to_mono(pcm)
    peak = _peak(pcm) or 1
    return _scale(pcm, (32767.0 * 10 ** (dbfs / 20.0)) / peak)


def write_wav(path: Path, pcm: bytes, channels: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)


def _ssl_context() -> ssl.SSLContext:
    """python.org builds on macOS ship without a CA bundle; certifi has one."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def load_key() -> str:
    """ELEVENLABS_API_KEY from the environment, else from the secrets file."""
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    if key or not ENV_FILE.exists():
        return key
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[len("export "):].strip()
        if "=" not in line or line.startswith("#"):
            continue
        name, value = line.split("=", 1)
        if name.strip() == "ELEVENLABS_API_KEY":
            return value.strip().strip("'\"")
    return ""


def request_for(name: str) -> dict:
    """The JSON body one clip is generated with."""
    if name in MUSIC:
        prompt, seconds = MUSIC[name]
        return {"text": prompt, "duration_seconds": min(30.0, seconds),
                "prompt_influence": 0.5, "loop": True, "model_id": MODEL}
    prompt, seconds = SOUNDS[name]
    return {"text": prompt,
            # the API floor is 0.5s; anything shorter gets trimmed here instead
            "duration_seconds": max(0.5, round(seconds + 0.2, 2)),
            "prompt_influence": 0.6, "model_id": MODEL}


def generate(body: dict, key: str) -> bytes:
    """One call to the sound-effects endpoint, retried once; raw 16-bit PCM."""
    data = json.dumps(body).encode()
    last = None
    for attempt in range(RETRIES + 1):
        req = urllib.request.Request(API, data=data, method="POST", headers={
            "xi-api-key": key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT, context=_ssl_context()) as r:
                return r.read()
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last = exc
            if attempt < RETRIES:
                time.sleep(2)
    raise RuntimeError(f"{last}")


def finish(name: str, raw: bytes) -> bytes:
    """Polish and level one clip as the game wants it."""
    if name in MUSIC:
        return polish_loop(raw, MUSIC_DBFS[name])
    pcm = polish(raw, SOUNDS[name][1])
    return _scale(pcm, 10 ** (MIX_DB[name] / 20.0))


LICENSES_HEAD = """# Audio provenance

> **Scope note.** The repository's `LICENSE` (MIT) covers the source code and
> the art. The audio files listed under **Licensed** below are **not** covered
> by it: they are licensed to Honest Arcade for use in Honest Solitaire, and no
> licence is granted to use them in another project.
>
> To make your own clips, the prompts, length budgets and mix levels are all
> in `tools/sfx.py`; the prompts used are in `PROMPTS.md`.

Every clip in `assets/audio/` is listed here. The audio guard
(`test/guards/audio_assets_test.dart`) fails the build if a clip the app plays
is missing, is not 44.1 kHz mono 16-bit PCM, or has no row below. This file
and `PROMPTS.md` do not ship inside the app: `pubspec.yaml` bundles the clips
one by one.

## Licensed

| File | Source | Licence |
|---|---|---|
"""


def record_licence(name: str, today: str) -> None:
    text = LICENSES.read_text() if LICENSES.exists() else LICENSES_HEAD
    row = (f"| `{name}.wav` | ElevenLabs text-to-sound-effects | "
           f"ElevenLabs {PLAN} plan, commercial licence |\n")
    text = re.sub(rf"^\| `{re.escape(name)}\.wav` \|.*\n", "", text, flags=re.M)
    text = text.replace("| File | Source | Licence |\n|---|---|---|\n",
                        "| File | Source | Licence |\n|---|---|---|\n" + row, 1)
    generated = (f"**Generated:** {today}, on an ElevenLabs **{PLAN}** "
                 f"subscription, model `{MODEL}` via `{ENDPOINT}`.\n")
    if "**Generated:**" in text:
        text = re.sub(r"^\*\*Generated:\*\*.*\n", generated, text, flags=re.M)
    else:
        text = text.rstrip("\n") + "\n\n" + generated
    LICENSES.write_text(text)


def record_prompt(name: str, body: dict, today: str) -> None:
    target = MUSIC[name][1] if name in MUSIC else SOUNDS[name][1]
    section = (f"## {name}\n\n"
               f"- Prompt: {body['text']}\n"
               f"- Requested: {body['duration_seconds']} s; target {target} s"
               f"{' (loop, untrimmed)' if body.get('loop') else ''}\n"
               f"- prompt_influence: {body['prompt_influence']}; loop: "
               f"{'yes' if body.get('loop') else 'no'}; model: {MODEL}\n"
               f"- Generated: {today}\n\n")
    head = ("# Prompts\n\nWhat each clip in this directory was generated from, "
            "by `tools/sfx.py` (#98). One take per prompt, no auditioning.\n\n")
    text = PROMPTS.read_text() if PROMPTS.exists() else head
    text = re.sub(rf"^## {re.escape(name)}\n.*?(?=^## |\Z)", "", text,
                  flags=re.M | re.S)
    PROMPTS.write_text(text.rstrip("\n") + "\n\n" + section)


def relevel() -> None:
    """Set the installed loop to its declared level. Idempotent."""
    import math
    for name, dbfs in MUSIC_DBFS.items():
        path = DEST / f"{name}.wav"
        with wave.open(str(path), "rb") as w:
            channels, frames = w.getnchannels(), w.getnframes()
            pcm = w.readframes(frames)
        peak = _peak(pcm) or 1
        before = 20 * math.log10(peak / 32767.0)
        write_wav(path, _scale(pcm, (32767.0 * 10 ** (dbfs / 20.0)) / peak), channels)
        print(f"  {name}.wav  {before:.1f} -> {dbfs:.1f} dBFS  {frames / RATE:.1f}s")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["generate", "relevel"])
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true",
                    help="overwrite a clip already in assets/audio/")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the requests and stop")
    args = ap.parse_args()

    if args.command == "relevel":
        relevel()
        return 0

    names = list(SOUNDS) + list(MUSIC)
    wanted = [k.strip() for k in args.only.split(",") if k.strip()] or names
    unknown = [k for k in wanted if k not in names]
    if unknown:
        print(f"unknown clip(s): {', '.join(unknown)}", file=sys.stderr)
        return 2
    bodies = {name: request_for(name) for name in wanted}
    if args.dry_run:
        for name, body in bodies.items():
            print(f"{name}: {json.dumps(body)}")
        return 0
    present = [n for n in wanted if (DEST / f"{n}.wav").exists()]
    if present and not args.force:
        print(f"sfx: already installed: {', '.join(present)} (use --force)", file=sys.stderr)
        return 2
    key = load_key()
    if not key:
        print(f"ELEVENLABS_API_KEY is not set and {ENV_FILE} has none", file=sys.stderr)
        return 2

    today = datetime.date.today().isoformat()
    STAGE.mkdir(parents=True, exist_ok=True)
    failed = []
    for name in wanted:
        try:
            pcm = finish(name, generate(bodies[name], key))
        except Exception as exc:  # noqa: BLE001 - report, install the rest
            print(f"  {name}: FAILED ({exc})")
            failed.append(name)
            continue
        write_wav(STAGE / f"{name}.wav", pcm)
        write_wav(DEST / f"{name}.wav", pcm)
        record_prompt(name, bodies[name], today)
        record_licence(name, today)
        print(f"  {name}.wav  {len(pcm) / 2 / RATE:.2f}s  installed")
    if failed:
        print(f"\n{len(failed)} failed; rerun with --only {','.join(failed)}",
              file=sys.stderr)
        return 1
    print(f"\n{len(wanted)} clips installed to {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
