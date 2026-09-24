"""ADR 0041: readiness, pinning, durable failures and guest-owned completion."""

import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, Mock

spec = importlib.util.spec_from_file_location(
    "worker",
    Path(__file__).resolve().parents[1]
    / "nixos/system/config/services/nixos-bootstrap/worker.py",
)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class BootstrapTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.config = self.root / "bootstrap.yaml"
        self.boot = self.root / "boot-id"
        self.boot.write_text("old")
        self.config.write_text(
            "schema_version: 1\nhostname: guest\nflake:\n  url: github:example/config\n  ref: trunk\nprerequisites:\n  files: []\n"
        )
        self.config.chmod(0o600)
        for name, value in [
            ("ROOT", self.root),
            ("CONFIG", self.config),
            ("BOOT_ID", self.boot),
        ]:
            p = patch.object(worker, name, value)
            p.start()
            self.addCleanup(p.stop)
        for name, value in [
            ("identity", {"machine_id": "a" * 32, "hostname": "guest"})
        ]:
            p = patch.object(worker, name, return_value=value)
            p.start()
            self.addCleanup(p.stop)
        # Files are owned by the test user; retain all permission validation.
        original_stat = Path.stat

        def owned_stat(path, *args, **kwargs):
            result = original_stat(path, *args, **kwargs)
            if path == self.config:
                fields = list(result)
                fields[4] = 0
                return os.stat_result(fields)
            return result

        p = patch.object(Path, "stat", owned_stat)
        p.start()
        self.addCleanup(p.stop)
        self.record = dict(
            machine_id="a" * 32,
            hostname="guest",
            attempt="b" * 32,
            revision="c" * 40,
            stage="booting",
            boot_id="old",
            system="/nix/store/final",
        )
        self.cloud = patch.object(
            worker.subprocess,
            "run",
            return_value=Mock(returncode=0, stdout='{"status":"done"}'),
        )
        self.cloud.start()
        self.addCleanup(self.cloud.stop)

    def test_missing_config_waits(self):
        self.config.unlink()
        with patch.object(worker, "command") as run:
            worker.dispatch(86400)
            run.assert_not_called()

    def test_missing_empty_directory_and_symlink_prerequisites_wait(self):
        target = self.root / "token"
        self.config.write_text(
            self.config.read_text().replace("files: []", f'files: ["{target}"]')
        )
        with patch.object(worker, "command") as run:
            for kind in ["missing", "empty", "directory", "symlink"]:
                with self.subTest(kind=kind):
                    if kind == "empty":
                        target.touch()
                    elif kind == "directory":
                        target.unlink()
                        target.mkdir()
                    elif kind == "symlink":
                        target.rmdir()
                        target.symlink_to(self.config)
                    worker.dispatch(86400)
            run.assert_not_called()
        self.assertFalse(worker.read_record("status"))

    def test_invalid_schema_and_hostname_do_not_build(self):
        for text in [
            "schema_version: true",
            "[]",
            self.config.read_text().replace("hostname: guest", "hostname: other"),
        ]:
            self.config.write_text(text)
            with self.assertRaises(ValueError):
                worker.dispatch(86400)
        self.assertFalse(worker.read_record("status"))

    def test_cloud_failure_does_not_build(self):
        with (
            patch.object(worker.subprocess, "run", return_value=Mock(returncode=2)),
            self.assertRaises(ValueError),
        ):
            worker.dispatch(86400)
        self.assertFalse(worker.read_record("status"))

    def test_build_pins_once_then_activates_boot_and_reboots(self):
        original_resolve = Path.resolve

        def resolve(path, *args, **kwargs):
            if path == self.root / "result":
                return Path("/nix/store/final")
            return original_resolve(path, *args, **kwargs)

        with (
            patch.object(worker, "command") as run,
            patch.object(Path, "resolve", resolve),
        ):
            run.return_value = json.dumps({"locked": {"rev": "c" * 40}})
            worker.dispatch(86400)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[0][0:3], ["nix", "flake", "metadata"])
        self.assertIn("/" + "c" * 40 + "#nixosConfigurations.guest", commands[1][-1])
        self.assertIn("--no-update-lock-file", commands[1])
        self.assertIn("--accept-flake-config", commands[0])
        self.assertIn("--refresh", commands[0])
        self.assertIn("--accept-flake-config", commands[1])
        self.assertEqual(
            commands[-2], ["/nix/store/final/bin/switch-to-configuration", "boot"]
        )
        self.assertEqual(commands[-1], ["systemctl", "reboot", "--no-block"])
        self.assertEqual(worker.read_record("status")["stage"], "booting")

    def test_failed_build_requires_explicit_retry(self):
        with patch.object(
            worker, "command", side_effect=RuntimeError("fetch failed")
        ) as run:
            with self.assertRaises(RuntimeError):
                worker.dispatch(86400)
            worker.dispatch(86400)
            run.assert_called_once()
        self.assertEqual(worker.read_record("status")["stage"], "failed")
        worker.retry()
        self.assertFalse(worker.read_record("status"))
        self.assertEqual(worker.read_record("previous-attempt")["stage"], "failed")
        with patch.object(worker, "command", side_effect=RuntimeError("stop after resolution")) as run:
            with self.assertRaises(RuntimeError):
                worker.dispatch(86400)
            self.assertIn("--refresh", run.call_args.args[0])

    def test_interrupted_attempt_becomes_failure(self):
        worker.write_record("status", self.record | {"stage": "building"})
        worker.dispatch(86400)
        self.assertEqual(worker.read_record("status")["stage"], "failed")

    def test_pending_reboot_cannot_retry(self):
        worker.write_record("status", self.record)
        with self.assertRaises(ValueError):
            worker.retry()
        with patch.object(worker, "command") as run:
            worker.dispatch(86400)
            run.assert_not_called()

    def test_completed_retry_cli_reports_actionable_error(self):
        worker.write_record("complete", self.record | {"stage": "complete"})
        previous_umask = os.umask(0o077)
        self.addCleanup(os.umask, previous_umask)
        with (
            patch("sys.argv", ["nixos-bootstrap", "retry"]),
            patch("sys.stderr", new_callable=io.StringIO) as error,
            self.assertRaises(SystemExit) as result,
        ):
            worker.cli()
        self.assertEqual(result.exception.code, 1)
        self.assertIn("already completed", error.getvalue())
        self.assertIn("systemctl start nixos-upgrade.service", error.getvalue())
        self.assertNotIn("Traceback", error.getvalue())
        self.assertEqual(worker.read_record("complete")["stage"], "complete")

    def test_completion_needs_new_boot_and_exact_closure(self):
        worker.write_record("status", self.record)
        with self.assertRaises(ValueError):
            worker.complete()
        self.boot.write_text("new")
        with patch.object(Path, "resolve", return_value=Path("/nix/store/final")):
            worker.complete()
        self.assertEqual(worker.read_record("complete")["stage"], "complete")
        with patch.object(
            Path, "resolve", return_value=Path("/nix/store/later-upgrade")
        ):
            worker.complete()
            worker.dispatch(86400)
        with self.assertRaises(ValueError):
            worker.retry()

    def test_foreign_machine_state_is_rejected(self):
        worker.write_record("complete", self.record | {"machine_id": "d" * 32})
        with self.assertRaises(ValueError):
            worker.dispatch(86400)

    def test_active_lock_blocks_dispatch_and_retry(self):
        previous_umask = os.umask(0o077)
        self.addCleanup(os.umask, previous_umask)
        with (self.root / "lock").open("a") as lock:
            worker.fcntl.flock(lock, worker.fcntl.LOCK_EX | worker.fcntl.LOCK_NB)
            with (
                patch("sys.argv", ["nixos-bootstrap", "run"]),
                patch.object(worker, "dispatch") as run,
            ):
                worker.main()
                run.assert_not_called()
            with (
                patch("sys.argv", ["nixos-bootstrap", "retry"]),
                self.assertRaises(ValueError),
            ):
                worker.main()

    def test_nonempty_regular_file_is_ready_without_reading_secret(self):
        path = self.root / "token"
        path.write_text("test-only")
        path.chmod(0o400)
        self.assertTrue(worker.file_ready(path))
        path.chmod(0o000)
        self.assertFalse(worker.file_ready(path))


if __name__ == "__main__":
    unittest.main()
