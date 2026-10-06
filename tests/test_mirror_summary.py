"""Check unavailable mirror-size measurements and filesystem statistics."""

import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "mirror_summary", Path(__file__).resolve().parents[1] / "nixos/hosts/mirror/collect-summary.py",
)
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)


class MirrorSummaryTest(unittest.TestCase):
    @mock.patch.object(summary.shutil, "disk_usage", return_value=(1000, 400, 600))
    @mock.patch.object(summary.subprocess, "run")
    def test_capacity_and_content_size(self, run, _usage):
        run.return_value.stdout = "300\t/srv/mirror\n"
        storage = summary.collect_storage(Path("/srv/mirror"))
        self.assertEqual(storage["content_bytes"], 300)
        self.assertEqual(storage["available_bytes"], 600)
        self.assertEqual(storage["used_bytes"], 400)

    @mock.patch.object(summary.shutil, "disk_usage", return_value=(1000, 400, 600))
    @mock.patch.object(summary.subprocess, "run", side_effect=subprocess.TimeoutExpired("du", 30))
    def test_content_timeout_keeps_capacity_and_marks_size_unavailable(self, _run, _usage):
        storage = summary.collect_storage(Path("/srv/mirror"))
        self.assertIsNone(storage["content_bytes"])
        self.assertEqual(storage["total_bytes"], 1000)


if __name__ == "__main__":
    unittest.main()
