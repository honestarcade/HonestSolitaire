#!/usr/bin/env python3
"""Sound generation (#98): ElevenLabs text-to-sound-effects into the game's
five clip names, post-processed to the lengths and levels the game expects.

Ported from Honest Sudoku's tools/sfx.py (its #49) with Honest Frog Across's
loop path and relevel added back. It is NOT reproducible -- the model returns
something new on every call -- so the committed WAVs are the artifacts of
record. M5 took one clip per prompt (owner, /n8-plan M5 round one); #115
adds rounds of variants for the owner to choose from. It is never run by CI
and needs the owner's key.

Usage:
  python3 tools/sfx.py generate [--only deal,flip] [--force] [--dry-run]
  python3 tools/sfx.py generate --only chime --prompt "<text>" --variants 3
  python3 tools/sfx.py --install chime build/sfx/chime-r1-v2.wav
  python3 tools/sfx.py relevel            # set the installed loop to MUSIC_DBFS

A plain `generate` installs one take per clip straight into assets/audio/.
With --variants N it installs nothing: it stages N takes of one new round as
build/sfx/<clip>-r<R>-v<N>.wav, each with a sidecar .json (prompt, request
settings, date), and adds the round to PROMPTS.md with the verdict pending.
--prompt replaces the built-in prompt and is refused with more than one
clip. --install copies the chosen take into assets/audio/, reading its
sidecar for the LICENSES.md date and the PROMPTS.md round it accepts.

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


def request_for(name: str, prompt: str = "") -> dict:
    """The JSON body one clip is generated with; [prompt] replaces the
    built-in one when given."""
    if name in MUSIC:
        default, seconds = MUSIC[name]
        return {"text": prompt or default, "duration_seconds": min(30.0, seconds),
                "prompt_influence": 0.5, "loop": True, "model_id": MODEL}
    default, seconds = SOUNDS[name]
    return {"text": prompt or default,
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
is missing, is not 44.1 kHz mono 16-bit PCM, or has no dated row below. This
file and `PROMPTS.md` do not ship inside the app: `pubspec.yaml` bundles the
clips one by one.

## Licensed

| File | Source | Licence | Date |
|---|---|---|---|
"""

TABLE_HEAD = "| File | Source | Licence | Date |\n|---|---|---|---|\n"


def record_licence(name: str, date: str) -> None:
    """The clip's row, dated the day its take was generated; one row per
    clip, the newest first."""
    text = LICENSES.read_text() if LICENSES.exists() else LICENSES_HEAD
    if TABLE_HEAD not in text:
        raise SystemExit(f"sfx: {LICENSES} has no dated Licensed table")
    row = (f"| `{name}.wav` | ElevenLabs text-to-sound-effects | "
           f"ElevenLabs {PLAN} plan, commercial licence | {date} |\n")
    text = re.sub(rf"^\| `{re.escape(name)}\.wav` \|.*\n", "", text, flags=re.M)
    text = text.replace(TABLE_HEAD, TABLE_HEAD + row, 1)
    generated = (f"**Generated** on an ElevenLabs **{PLAN}** subscription, "
                 f"model `{MODEL}` via `{ENDPOINT}`; each row's date is the "
                 f"day that clip was generated.\n")
    if re.search(r"^\*\*Generated", text, flags=re.M):
        text = re.sub(r"^\*\*Generated.*\n", generated, text, flags=re.M)
    else:
        text = text.rstrip("\n") + "\n\n" + generated
    LICENSES.write_text(text)


PROMPTS_HEAD = """# Prompts

What each clip in this directory was generated from, by `tools/sfx.py`, one
table per clip. Round 0 is M5's single take (#98); each later round is one
prompt generated as a set of variants for the owner to choose from (#115),
with the owner's verdict. Only an accepted variant is installed.
"""

ROUND_HEAD = ("| Round | Prompt | Settings | Date | Variants | Verdict |\n"
              "|---|---|---|---|---|---|\n")


def _cell(text) -> str:
    return str(text).replace("|", "\\|").replace("\n", " ")


def settings_of(body: dict) -> str:
    """The request's settings as one table cell."""
    return (f"{body['duration_seconds']} s, prompt_influence "
            f"{body['prompt_influence']}, loop "
            f"{'yes' if body.get('loop') else 'no'}, {body['model_id']}")


def _section(text: str, name: str):
    """The (start, end) of clip [name]'s section in [text], or None."""
    m = re.search(rf"^## {re.escape(name)}\n", text, flags=re.M)
    if not m:
        return None
    nxt = re.search(r"^## ", text[m.end():], flags=re.M)
    return m.start(), (m.end() + nxt.start()) if nxt else len(text)


def rounds_of(name: str) -> dict:
    """Round number -> its table row, for clip [name] in PROMPTS.md."""
    if not PROMPTS.exists():
        return {}
    text = PROMPTS.read_text()
    span = _section(text, name)
    if span is None:
        return {}
    out = {}
    for line in text[span[0]:span[1]].splitlines():
        m = re.match(r"^\| (\d+) \|", line)
        if m:
            out[int(m.group(1))] = line
    return out


def next_round(name: str) -> int:
    """One past the highest round recorded in PROMPTS.md or staged."""
    seen = list(rounds_of(name))
    if STAGE.exists():
        for side in STAGE.glob(f"{name}-r*-v*.json"):
            m = re.fullmatch(rf"{re.escape(name)}-r(\d+)-v\d+\.json", side.name)
            if m:
                seen.append(int(m.group(1)))
    return max(seen, default=-1) + 1


def record_round(name: str, rnd: int, body: dict, date: str,
                 variants: int, verdict: str) -> None:
    """Writes, or rewrites, round [rnd] of clip [name]'s table."""
    text = PROMPTS.read_text() if PROMPTS.exists() else PROMPTS_HEAD
    row = (f"| {rnd} | {_cell(body['text'])} | {_cell(settings_of(body))} | "
           f"{date} | {variants} | {_cell(verdict)} |")
    span = _section(text, name)
    if span is None:
        text = text.rstrip("\n") + f"\n\n## {name}\n\n{ROUND_HEAD}{row}\n"
    else:
        lines = text[span[0]:span[1]].rstrip("\n").split("\n")
        at = [i for i, ln in enumerate(lines) if ln.startswith(f"| {rnd} |")]
        if at:
            lines[at[0]] = row
        elif any(ln.startswith("|---") for ln in lines):
            last = max(i for i, ln in enumerate(lines) if ln.startswith("|"))
            lines.insert(last + 1, row)
        else:
            lines += ["", *ROUND_HEAD.rstrip("\n").split("\n"), row]
        rest = text[span[1]:]
        text = text[:span[0]] + "\n".join(lines) + "\n" + ("\n" + rest if rest else "")
    PROMPTS.write_text(text.rstrip("\n") + "\n")


def set_verdict(name: str, rnd: int, verdict: str) -> bool:
    """Rewrites the verdict cell of round [rnd]; False when there is no
    such row."""
    row = rounds_of(name).get(rnd)
    if row is None:
        return False
    head, _ = row.rstrip().rstrip("|").rstrip().rsplit(" | ", 1)
    text = PROMPTS.read_text().replace(row, f"{head} | {_cell(verdict)} |", 1)
    PROMPTS.write_text(text)
    return True


def stage_variants(name: str, body: dict, count: int, key: str,
                   today: str) -> list:
    """Generates [count] takes of one new round into build/sfx/, each with
    its sidecar, and records the round as pending. Returns the WAV paths."""
    rnd = next_round(name)
    STAGE.mkdir(parents=True, exist_ok=True)
    written = []
    for n in range(1, count + 1):
        pcm = finish(name, generate(body, key))
        wav = STAGE / f"{name}-r{rnd}-v{n}.wav"
        write_wav(wav, pcm)
        wav.with_suffix(".json").write_text(json.dumps({
            "clip": name, "round": rnd, "variant": n, "prompt": body["text"],
            "settings": body, "date": today}, indent=2) + "\n")
        written.append(wav)
        print(f"  {wav.name}  {len(pcm) / 2 / RATE:.2f}s  staged")
    record_round(name, rnd, body, today, count, "pending")
    return written


def install(name: str, wav: Path) -> int:
    """Installs a staged take the owner chose, from its sidecar."""
    side = wav.with_suffix(".json")
    if not wav.is_file() or not side.is_file():
        print(f"sfx: {wav} and its sidecar {side.name} must both exist",
              file=sys.stderr)
        return 2
    meta = json.loads(side.read_text())
    if meta.get("clip") != name:
        print(f"sfx: {wav.name} is a take of {meta.get('clip')!r}, not {name!r}",
              file=sys.stderr)
        return 2
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / f"{name}.wav").write_bytes(wav.read_bytes())
    record_licence(name, meta["date"])
    verdict = f"accepted: v{meta['variant']}"
    if not set_verdict(name, meta["round"], verdict):
        record_round(name, meta["round"], meta["settings"], meta["date"], 1,
                     verdict)
    print(f"  {name}.wav  round {meta['round']} v{meta['variant']}  installed")
    return 0


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


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", nargs="?", choices=["generate", "relevel"])
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true",
                    help="overwrite a clip already in assets/audio/")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the requests and stop")
    ap.add_argument("--prompt", default="",
                    help="replace the built-in prompt (one clip only)")
    ap.add_argument("--variants", type=int, default=0,
                    help="stage N takes as one round instead of installing")
    ap.add_argument("--install", nargs=2, metavar=("CLIP", "FILE"),
                    help="install a staged take, reading its sidecar")
    args = ap.parse_args(argv)

    names = list(SOUNDS) + list(MUSIC)
    if args.install:
        if args.command:
            print("sfx: --install takes no command", file=sys.stderr)
            return 2
        clip, path = args.install
        if clip not in names:
            print(f"unknown clip: {clip}", file=sys.stderr)
            return 2
        return install(clip, Path(path))
    if args.command is None:
        print("sfx: a command (generate, relevel) or --install is required",
              file=sys.stderr)
        return 2
    if args.command == "relevel":
        relevel()
        return 0

    wanted = [k.strip() for k in args.only.split(",") if k.strip()] or names
    unknown = [k for k in wanted if k not in names]
    if unknown:
        print(f"unknown clip(s): {', '.join(unknown)}", file=sys.stderr)
        return 2
    if args.prompt and len(wanted) != 1:
        print("sfx: --prompt needs exactly one clip in --only", file=sys.stderr)
        return 2
    if args.variants < 0:
        print("sfx: --variants must be at least 1", file=sys.stderr)
        return 2
    bodies = {name: request_for(name, args.prompt) for name in wanted}
    if args.dry_run:
        for name, body in bodies.items():
            print(f"{name}: {json.dumps(body)}")
        return 0
    present = [n for n in wanted if (DEST / f"{n}.wav").exists()]
    if present and not args.force and not args.variants:
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
            if args.variants:
                stage_variants(name, bodies[name], args.variants, key, today)
                continue
            pcm = finish(name, generate(bodies[name], key))
        except Exception as exc:  # noqa: BLE001 - report, do the rest
            print(f"  {name}: FAILED ({exc})")
            failed.append(name)
            continue
        write_wav(STAGE / f"{name}.wav", pcm)
        write_wav(DEST / f"{name}.wav", pcm)
        record_round(name, next_round(name), bodies[name], today, 1,
                     "installed, not yet heard by the owner")
        record_licence(name, today)
        print(f"  {name}.wav  {len(pcm) / 2 / RATE:.2f}s  installed")
    if failed:
        print(f"\n{len(failed)} failed; rerun with --only {','.join(failed)}",
              file=sys.stderr)
        return 1
    if args.variants:
        print(f"\nstaged in {STAGE}; install the chosen take with --install")
    else:
        print(f"\n{len(wanted)} clips installed to {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
