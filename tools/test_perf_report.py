"""Unit tests for tools/perf_report.py (#117): the statistics the 95 % target
is judged by, and the report's verdicts.

Run with `python3 -m unittest discover -s tools -p 'test_*.py'`.
"""
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))

import perf_report  # noqa: E402


def row(draw, ms, verdict="within", found=1, tried=1):
    return {"draw": draw, "base": 1000, "found": found, "ms": ms,
            "dealsTried": tried, "verdict": verdict}


class Statistics(unittest.TestCase):
    def test_median_of_an_even_count_is_the_mean_of_the_middle_two(self):
        self.assertEqual(perf_report.median([4, 1, 3, 2]), 2.5)

    def test_median_of_an_odd_count_is_the_middle(self):
        self.assertEqual(perf_report.median([9, 1, 5]), 5.0)

    def test_p95_is_the_nearest_rank(self):
        values = list(range(1, 101))
        self.assertEqual(perf_report.p95(values), 95)
        self.assertEqual(perf_report.p95([7]), 7)
        self.assertEqual(perf_report.p95(list(range(1, 21))), 19)


class Target(unittest.TestCase):
    def test_95_within_of_100_meets_the_target(self):
        rows = [row(1, 100)] * 95 + [row(1, 6000, "late")] * 5
        self.assertTrue(perf_report.summarise(rows)["meets_target"])

    def test_94_within_misses_and_every_other_verdict_is_a_miss(self):
        rows = ([row(1, 100)] * 94 + [row(1, 6000, "late")] * 2
                + [row(1, 60000, "timeout", found=None, tried=None)] * 2
                + [row(1, 10, "notFound", found=None, tried=None)]
                + [row(1, 10, "error: boom", found=None, tried=None)])
        s = perf_report.summarise(rows)
        self.assertEqual(s["within"], 94)
        self.assertEqual(s["misses"], 6)
        self.assertFalse(s["meets_target"])

    def test_times_are_over_found_searches_only(self):
        rows = [row(1, 100), row(1, 300), row(1, 60000, "timeout", found=None, tried=None)]
        s = perf_report.summarise(rows)
        self.assertEqual(s["ms_max"], 300)


class Report(unittest.TestCase):
    def run_main(self, run):
        with tempfile.TemporaryDirectory() as d:
            src = pathlib.Path(d, "run.json")
            out = pathlib.Path(d, "out.md")
            src.write_text(json.dumps(run))
            code = perf_report.main(["perf_report.py", str(src), str(out), "Device=emu"])
            return code, out.read_text()

    def test_a_golden_mismatch_fails_and_is_named(self):
        code, text = self.run_main({"golden": {"checked": 35, "mismatches": ["spider-4 deal 2 (first differing pile: stock)"]}})
        self.assertEqual(code, 1)
        self.assertIn("MISMATCH", text)
        self.assertIn("spider-4 deal 2", text)

    def test_a_clean_run_reports_each_draw_mode_separately(self):
        rows = [row(1, 100)] * 20 + [row(3, 100)] * 18 + [row(3, 7000, "late")] * 2
        code, text = self.run_main({"golden": {"checked": 35, "mismatches": []}, "searches": rows})
        self.assertEqual(code, 0)
        self.assertIn("| 1 | 20 | 20 | 100.0% | met |", text)
        self.assertIn("| 3 | 20 | 18 | 90.0% | MISSED |", text)
        self.assertIn("- **Device:** emu", text)


if __name__ == "__main__":
    unittest.main()
