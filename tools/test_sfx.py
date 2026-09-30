"""Offline unit tests for tools/sfx.py (#98, #115): its helpers, and the
generate/--install paths with the ElevenLabs call stubbed out. The real call
talks to a paid, non-reproducible API and has no test.

Run with `python3 -m unittest discover -s tools -p 'test_*.py'`.
"""
import contextlib
import io
import json
import os
import pathlib
import shutil
import struct
import sys
import tempfile
import unittest
import unittest.mock
import wave

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import sfx  # noqa: E402


def pcm(*samples):
    return b"".join(struct.pack("<h", s) for s in samples)


class Helpers(unittest.TestCase):
    def test_peak_handles_the_negative_extreme(self):
        self.assertEqual(sfx._peak(pcm(0, 100, -300)), 300)
        self.assertEqual(sfx._peak(pcm(-32768, 5)), 32768)
        self.assertEqual(sfx._peak(b""), 0)

    def test_scale_clamps_and_ignores_an_odd_trailing_byte(self):
        self.assertEqual(sfx._scale(pcm(1000, -1000), 2.0), pcm(2000, -2000))
        self.assertEqual(sfx._scale(pcm(30000), 2.0), pcm(32767))
        self.assertEqual(sfx._scale(pcm(-30000), 2.0), pcm(-32768))
        self.assertEqual(sfx._scale(pcm(4) + b"\x01", 1.0), pcm(4) + b"\x00")

    def test_to_mono_averages_the_pair(self):
        self.assertEqual(sfx._to_mono(pcm(100, 300, -100, -300)), pcm(200, -200))
        self.assertEqual(sfx._to_mono(b""), b"")

    def test_polish_trims_leading_silence_cuts_fades_and_normalises(self):
        silence = pcm(*([0, 0] * 2205))  # 50 ms of stereo silence
        tone = pcm(*([8000, 8000, -8000, -8000] * 4410))  # 200 ms stereo
        out = sfx.polish(silence + tone, 0.1)
        self.assertLessEqual(len(out), int(0.1 * sfx.RATE) * 2)
        self.assertGreater(len(out), 0)
        peak = sfx._peak(out)
        self.assertAlmostEqual(peak / 32767, 0.89, delta=0.02)
        # the last sample is faded to (near) nothing
        self.assertLess(abs(struct.unpack_from("<h", out, len(out) - 2)[0]), 400)
        self.assertEqual(sfx.polish(b"", 0.1), b"")

    def test_polish_loop_sets_the_absolute_level_and_keeps_the_length(self):
        stereo = pcm(*([1000, 1000, -1000, -1000] * 1000))
        out = sfx.polish_loop(stereo, -15.0)
        self.assertEqual(len(out), len(stereo) // 2)
        self.assertAlmostEqual(20 * __import__("math").log10(sfx._peak(out) / 32767), -15.0, delta=0.1)

    def test_write_wav_is_44100_mono_16_bit(self):
        with tempfile.TemporaryDirectory() as d:
            path = pathlib.Path(d) / "a.wav"
            sfx.write_wav(path, pcm(1, -32768, 3))
            with wave.open(str(path), "rb") as w:
                self.assertEqual((w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()), (1, 2, 44100, 3))
                self.assertEqual(w.readframes(3), pcm(1, -32768, 3))
            sfx.write_wav(path, b"")
            with wave.open(str(path), "rb") as w:
                self.assertEqual(w.getnframes(), 0)

    def test_requests_carry_the_model_and_the_loop_flag(self):
        self.assertEqual(sfx.request_for("snap")["duration_seconds"], 0.5)
        self.assertEqual(sfx.request_for("chime")["duration_seconds"], 1.1)
        self.assertNotIn("loop", sfx.request_for("deal"))
        music = sfx.request_for("music")
        self.assertTrue(music["loop"])
        self.assertEqual(music["duration_seconds"], 30.0)
        self.assertEqual(music["model_id"], sfx.MODEL)


class Rounds(unittest.TestCase):
    """generate --prompt/--variants and --install, in a scratch tree with
    the network call replaced."""

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        dest = self.tmp / "assets" / "audio"
        dest.mkdir(parents=True)
        real = pathlib.Path(sfx.__file__).resolve().parent.parent / "assets" / "audio"
        for name in ("LICENSES.md", "PROMPTS.md"):
            shutil.copy(real / name, dest / name)
        saved = {k: getattr(sfx, k) for k in
                 ("ROOT", "DEST", "STAGE", "LICENSES", "PROMPTS", "generate")}
        self.addCleanup(lambda: [setattr(sfx, k, v) for k, v in saved.items()])
        sfx.ROOT = self.tmp
        sfx.DEST = dest
        sfx.STAGE = self.tmp / "build" / "sfx"
        sfx.LICENSES = dest / "LICENSES.md"
        sfx.PROMPTS = dest / "PROMPTS.md"
        self.calls = []

        def fake(body, key):
            self.calls.append(body)
            n = len(self.calls)  # each take differs, as the real API's do
            return pcm(*([0, 0] * 50 + [4000 + n, 4000 + n] * 4000))

        sfx.generate = fake
        env = dict(os.environ, ELEVENLABS_API_KEY="test-key")
        patcher = unittest.mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)

    def run_sfx(self, *argv):
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            code = sfx.main(list(argv))
        return code, err.getvalue()

    def prompts(self):
        return sfx.PROMPTS.read_text()

    def test_prompt_is_refused_with_more_than_one_clip(self):
        code, err = self.run_sfx("generate", "--only", "deal,flip", "--prompt", "x")
        self.assertEqual(code, 2)
        self.assertIn("exactly one clip", err)
        code, _ = self.run_sfx("generate", "--prompt", "x")  # every clip
        self.assertEqual(code, 2)
        self.assertEqual(self.calls, [])

    def test_prompt_replaces_the_built_in_one(self):
        self.assertEqual(sfx.request_for("chime", "a soft bell")["text"], "a soft bell")
        self.assertEqual(sfx.request_for("chime")["text"], sfx.SOUNDS["chime"][0])
        self.assertEqual(sfx.request_for("music", "rain")["text"], "rain")
        self.assertTrue(sfx.request_for("music", "rain")["loop"])

    def test_variants_stage_a_round_with_sidecars_and_install_nothing(self):
        before = (sfx.DEST / "LICENSES.md").read_text()
        code, _ = self.run_sfx("generate", "--only", "chime", "--force",
                               "--prompt", "a soft | bell", "--variants", "3")
        self.assertEqual(code, 0)
        self.assertEqual(len(self.calls), 3)
        self.assertTrue(all(b["text"] == "a soft | bell" for b in self.calls))
        for n in (1, 2, 3):
            wav = sfx.STAGE / f"chime-r1-v{n}.wav"
            self.assertTrue(wav.is_file(), wav)
            meta = json.loads(wav.with_suffix(".json").read_text())
            self.assertEqual((meta["clip"], meta["round"], meta["variant"]), ("chime", 1, n))
            self.assertEqual(meta["prompt"], "a soft | bell")
            self.assertEqual(meta["settings"]["prompt_influence"], 0.6)
            self.assertRegex(meta["date"], r"^\d{4}-\d{2}-\d{2}$")
        self.assertFalse((sfx.DEST / "chime.wav").exists())
        self.assertEqual((sfx.DEST / "LICENSES.md").read_text(), before)
        rows = sfx.rounds_of("chime")
        self.assertEqual(sorted(rows), [0, 1])
        self.assertIn("a soft \\| bell", rows[1])
        self.assertTrue(rows[1].endswith("| 3 | pending |"), rows[1])
        # the other clips' tables are untouched
        self.assertEqual(sorted(sfx.rounds_of("snap")), [0])
        # a second round numbers on
        self.run_sfx("generate", "--only", "chime", "--prompt", "y", "--variants", "3")
        self.assertTrue((sfx.STAGE / "chime-r2-v3.wav").is_file())
        self.assertEqual(sorted(sfx.rounds_of("chime")), [0, 1, 2])

    def test_install_reads_the_sidecar(self):
        self.run_sfx("generate", "--only", "flip", "--prompt", "p", "--variants", "3")
        side = sfx.STAGE / "flip-r1-v2.json"
        meta = json.loads(side.read_text())
        meta["date"] = "2026-10-02"
        side.write_text(json.dumps(meta))
        code, _ = self.run_sfx("--install", "flip", str(sfx.STAGE / "flip-r1-v2.wav"))
        self.assertEqual(code, 0)
        self.assertEqual((sfx.DEST / "flip.wav").read_bytes(),
                         (sfx.STAGE / "flip-r1-v2.wav").read_bytes())
        licences = sfx.LICENSES.read_text()
        self.assertIn("| `flip.wav` | ElevenLabs text-to-sound-effects | "
                      "ElevenLabs Creator plan, commercial licence | 2026-10-02 |",
                      licences)
        self.assertEqual(licences.count("`flip.wav`"), 1)
        self.assertIn("| `snap.wav` |", licences)
        self.assertTrue(sfx.rounds_of("flip")[1].endswith("| accepted: v2 |"))
        self.assertTrue(sfx.rounds_of("flip")[0].endswith("owner's verdict pending (#115) |"))

    def test_install_refuses_a_take_of_another_clip_or_without_a_sidecar(self):
        self.run_sfx("generate", "--only", "snap", "--prompt", "p", "--variants", "1")
        wav = sfx.STAGE / "snap-r1-v1.wav"
        code, err = self.run_sfx("--install", "deal", str(wav))
        self.assertEqual(code, 2)
        self.assertIn("take of 'snap'", err)
        wav.with_suffix(".json").unlink()
        code, err = self.run_sfx("--install", "snap", str(wav))
        self.assertEqual(code, 2)
        self.assertIn("sidecar", err)
        self.assertFalse((sfx.DEST / "snap.wav").exists())

    def test_a_plain_generate_still_installs_and_records_a_dated_row(self):
        code, _ = self.run_sfx("generate", "--only", "deal")
        self.assertEqual(code, 0)
        self.assertTrue((sfx.DEST / "deal.wav").is_file())
        row = [ln for ln in sfx.LICENSES.read_text().splitlines() if "`deal.wav`" in ln]
        self.assertEqual(len(row), 1)
        self.assertRegex(row[0], r"\| \d{4}-\d{2}-\d{2} \|$")
        self.assertEqual(sorted(sfx.rounds_of("deal")), [0, 1])
        code, err = self.run_sfx("generate", "--only", "deal")
        self.assertEqual(code, 2)
        self.assertIn("--force", err)


if __name__ == "__main__":
    unittest.main()
