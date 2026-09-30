"""Unit tests for tools/mutation_check.py's binary mutation kinds (#97).

Run with `python3 -m unittest discover -s tools -p 'test_*.py'`.
"""
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mutation_check  # noqa: E402


class BinaryRoundTrip(unittest.TestCase):
    def test_a_deleted_file_comes_back_byte_identical(self):
        with tempfile.TemporaryDirectory() as d:
            target = pathlib.Path(d) / "res" / "icon.png"
            target.parent.mkdir()
            data = bytes(range(256)) * 7
            target.write_bytes(data)
            snap = mutation_check.snapshot_bytes([target])
            target.unlink()
            target.parent.rmdir()
            self.assertFalse(target.exists())
            mutation_check.restore_bytes(snap)
            self.assertEqual(target.read_bytes(), data)

    def test_a_replaced_file_comes_back_byte_identical(self):
        with tempfile.TemporaryDirectory() as d:
            target = pathlib.Path(d) / "icon.png"
            data = b"\x89PNG original"
            target.write_bytes(data)
            snap = mutation_check.snapshot_bytes([target])
            target.write_bytes(b"template bytes")
            mutation_check.restore_bytes(snap)
            self.assertEqual(target.read_bytes(), data)


class CreatedTargets(unittest.TestCase):
    def mutation(self, target, creates):
        return mutation_check.Mutation(
            "#test", "x", "", None, "why",
            replaces_with=((target, "fixture"),), creates=creates)

    def test_a_new_file_named_in_creates_may_be_absent(self):
        target = "qa/runs/not-there-yet.md"
        m = self.mutation(target, (target,))
        self.assertEqual(
            mutation_check.missing_targets(m, [mutation_check.ROOT / target]), [])

    def test_an_absent_target_not_in_creates_is_missing(self):
        target = "qa/runs/not-there-yet.md"
        m = self.mutation(target, ())
        path = mutation_check.ROOT / target
        self.assertEqual(mutation_check.missing_targets(m, [path]), [path])


if __name__ == "__main__":
    unittest.main()
