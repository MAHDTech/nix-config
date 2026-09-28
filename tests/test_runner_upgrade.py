"""Run the actual upgrade script with fake external commands."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "nixos/hosts/github-runner/common/upgrade.sh"


class UpgradeTest(unittest.TestCase):
    def run_upgrade(self, *, changed=True, switched=False, build_result=0,
                    drain_result=0, staged_changed=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "commands"
            drain_side_effect = 'touch "$STATE_DIR/staged-changed"; ' if staged_changed else ""
            commands = {
                "nixos-rebuild": f'echo "build $*" >> "$COMMAND_LOG"; exit {build_result}',
                "readlink": 'case "$2" in\n'
                '  /nix/var/nix/profiles/system) '
                'if test -f "$STATE_DIR/staged-changed"; then '
                'echo /nix/store/other-system; else echo /nix/store/new-system; fi;;\n'
                f'  /run/booted-system) echo /nix/store/{"old" if changed else "new"}-system;;\n'
                f'  /run/current-system) echo /nix/store/{"other" if switched else "old" if changed else "new"}-system;;\n'
                '  *) exit 2;;\nesac',
                "nixos-drain": f'echo "drain $*" >> "$COMMAND_LOG"; '
                f'{drain_side_effect}exit {drain_result}',
                "systemctl": 'echo "systemctl $*" >> "$COMMAND_LOG"',
            }
            for name, body in commands.items():
                executable = root / name
                executable.write_text(f"#!/bin/sh\n{body}\n")
                executable.chmod(0o755)
            environment = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                               COMMAND_LOG=str(log), RUNNER_FLAKE="github:example/config",
                               RUNNER_HOST="github-runner-20", STATE_DIR=str(root))
            result = subprocess.run(["bash", str(SCRIPT)], env=environment,
                                    text=True, capture_output=True)
            return result, log.read_text().splitlines() if log.exists() else []

    def test_unchanged_generation_does_not_drain_or_reboot(self):
        result, commands = self.run_upgrade(changed=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(commands), 1)
        self.assertIn("already booted", result.stdout)

    def test_changed_generation_drains_before_reboot(self):
        result, commands = self.run_upgrade()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--flake github:example/config#github-runner-20", commands[0])
        self.assertEqual(commands[1:], ["drain drain --profile upgrade", "systemctl reboot --no-block"])

    def test_build_failure_does_not_drain_or_reboot(self):
        result, commands = self.run_upgrade(build_result=7)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(len(commands), 1)

    def test_manual_switch_away_from_booted_generation_still_requires_reboot(self):
        result, commands = self.run_upgrade(changed=False, switched=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands[-1], "systemctl reboot --no-block")

    def test_failed_drain_does_not_reboot(self):
        result, commands = self.run_upgrade(drain_result=1)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(commands), 2)
        self.assertEqual(commands[-1], "drain drain --profile upgrade")

    def test_changed_staged_generation_does_not_reboot(self):
        result, commands = self.run_upgrade(staged_changed=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(commands), 2)
        self.assertIn("Staged system changed", result.stderr)


if __name__ == "__main__":
    unittest.main()
