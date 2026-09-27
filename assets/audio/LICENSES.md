# Audio provenance

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
| `music.wav` | ElevenLabs text-to-sound-effects | ElevenLabs Creator plan, commercial licence |
| `chime.wav` | ElevenLabs text-to-sound-effects | ElevenLabs Creator plan, commercial licence |
| `snap.wav` | ElevenLabs text-to-sound-effects | ElevenLabs Creator plan, commercial licence |
| `flip.wav` | ElevenLabs text-to-sound-effects | ElevenLabs Creator plan, commercial licence |
| `deal.wav` | ElevenLabs text-to-sound-effects | ElevenLabs Creator plan, commercial licence |

**Generated:** 2026-09-27, on an ElevenLabs **Creator** subscription, model `eleven_text_to_sound_v2` via `POST /v1/sound-generation`.
