"""Offline unit tests for tools/sfx.py's helpers (#98). The generation itself
talks to a paid, non-reproducible API and has no test.

Run with `python3 -m unittest discover -s tools -p 'test_*.py'`.
"""
import pathlib
import struct
import sys
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main()
