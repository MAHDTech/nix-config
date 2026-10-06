"""Exercise service stop ordering and recovery using the production shell handler."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "nixos/system/config/services/nixos-drain/service-profile.sh"


class ServiceDrainTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.state = self.root / "state"
        self.log = self.root / "commands"
        systemctl = self.root / "systemctl"
        systemctl.write_text('''#!/bin/sh
echo "$*" >> "$COMMAND_LOG"
case "$1" in
  show)
    if [ "$3" = --property=ActiveState ]; then
      if [ "$2" = "$INACTIVE_UNIT" ]; then echo inactive; else echo active; fi
    elif [ "$2" = "$FAILED_UNIT" ]; then echo timeout; else echo success; fi;;
  start) if [ "$2" = "$START_FAILURE" ]; then exit 1; fi;;
esac
''')
        systemctl.chmod(0o755)
        self.environment = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                                SERVICE_DRAIN_STATE=str(self.state), COMMAND_LOG=str(self.log))
        self.units = ["provision.timer", "provision.service", "nginx.service", "backend.service"]

    def run_handler(self, mode, **environment):
        return subprocess.run(["bash", str(SCRIPT), mode, *self.units],
                              env=self.environment | environment, capture_output=True, text=True)

    def mutations(self):
        return [line for line in self.log.read_text().splitlines()
                if line.startswith(("stop ", "start "))]

    def test_stop_order_and_reverse_restore_preserve_inactive_services(self):
        result = self.run_handler("drain", INACTIVE_UNIT="provision.service")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.state / "blocked").exists())
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o755)
        result = self.run_handler("cancel")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [f"stop {unit}" for unit in self.units] +
                         ["start backend.service", "start nginx.service", "start provision.timer"])
        self.assertFalse(self.state.exists())
        self.assertEqual(self.run_handler("cancel").returncode, 0)

    def test_unclean_proxy_stop_does_not_stop_backend(self):
        result = self.run_handler("drain", FAILED_UNIT="nginx.service")
        self.assertEqual(result.returncode, 1)
        self.assertIn("nginx.service did not stop cleanly: timeout", result.stderr)
        self.assertNotIn("stop backend.service", self.mutations())
        self.assertTrue((self.state / "restore").exists())
        self.assertEqual(self.run_handler("cancel").returncode, 0)

    def test_failed_restore_can_be_retried(self):
        self.assertEqual(self.run_handler("drain").returncode, 0)
        self.assertEqual(self.run_handler("cancel", START_FAILURE="nginx.service").returncode, 1)
        self.assertTrue((self.state / "restore").exists())
        self.assertFalse((self.state / "blocked").exists())
        self.assertEqual(self.run_handler("cancel").returncode, 0)
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
