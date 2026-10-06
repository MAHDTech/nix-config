"""Exercise drain scripts, request ownership, failure and cancellation contracts."""

# cspell:ignore geteuid

import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
import uuid
from unittest.mock import patch


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parents[1] / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


drain = load("drain", "nixos/system/config/services/nixos-drain/drain.py")
runner = load("runner_drain", "nixos/system/config/services/github-runner/drain.py")


class DrainTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        for module, attribute, value in (
            (drain, "ROOT", self.root),
            (drain, "CONFIG", self.root / "config.json"),
            (runner, "ROOT", self.root),
            (runner, "CONFIG", self.root / "runner-config.json"),
        ):
            replacement = patch.object(module, attribute, value)
            replacement.start()
            self.addCleanup(replacement.stop)
        self.configure()
        launch = patch.object(drain, "launch", side_effect=self.launch)
        self.launch_mock = launch.start()
        self.addCleanup(launch.stop)

    def script(self, name, text):
        path = self.root / name
        path.write_text(f"#!{os.environ.get('SHELL', '/bin/sh')}\nset -eu\n{text}\n")
        path.chmod(0o755)
        return str(path)

    def configure(self, script="true", cancel="true", timeout=1, cancel_on_failure=False):
        profile = {
            "script": self.script("drain.sh", script),
            "cancelScript": self.script("cancel.sh", cancel),
            "timeoutSeconds": timeout,
            "notificationOnly": script == "true",
            "cancelOnFailure": cancel_on_failure,
        }
        drain.CONFIG.write_text(json.dumps(dict(upgrade=profile, destroy=profile)))

    @staticmethod
    def launch(state, phase):
        state["unit"] = f"test-{phase}-{uuid.uuid4().hex}"
        drain.save(state)

    def work(self, attempt, phase="draining"):
        # Keep real script execution; replace only wall and systemctl interactions.
        with patch.object(drain.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "not-found\n")):
            drain.worker(attempt, phase, drain.read()["unit"])

    def test_notification_profile_and_duplicate_success(self):
        attempt = drain.request("upgrade")
        self.work(attempt)
        self.assertEqual(drain.wait(attempt, "drained"), 0)
        self.assertIn("Notification only", drain.read()["progress"])
        self.assertEqual(drain.request("upgrade"), attempt)
        self.assertEqual(self.launch_mock.call_count, 1)

    def test_join_same_request_reject_other_and_unknown(self):
        attempt = drain.request("upgrade")
        self.assertEqual(drain.request("upgrade"), attempt)
        for profile in ("destroy", "unknown"):
            with self.assertRaises(RuntimeError):
                drain.request(profile)
        self.assertEqual(self.launch_mock.call_count, 1)

    def test_exclusive_request_does_not_join_an_existing_drain(self):
        attempt = drain.request("upgrade", exclusive=True)
        with self.assertRaises(RuntimeError):
            drain.request("upgrade", exclusive=True)
        self.work(attempt)
        with self.assertRaises(RuntimeError):
            drain.request("upgrade", exclusive=True)
        self.assertEqual(drain.read()["attempt"], attempt)

    def test_guarded_cancel_cannot_cancel_another_attempt(self):
        attempt = drain.request("upgrade")
        with self.assertRaises(RuntimeError):
            drain.cancel("wrong-attempt")
        self.assertEqual(drain.read()["state"], "draining")
        self.assertEqual(drain.cancel(attempt), attempt)

    def test_owned_cli_interruption_cancels_its_attempt(self):
        output = io.StringIO()
        with patch("sys.argv", ["nixos-drain", "drain", "--profile", "upgrade", "--owned"]), \
             patch.object(drain.os, "geteuid", return_value=0), \
             patch("sys.stdout", output), \
             patch.object(drain, "wait", side_effect=[KeyboardInterrupt, 0]) as wait:
            self.assertEqual(drain.main(), 130)
        attempt = output.getvalue().strip()
        self.assertEqual(drain.read()["attempt"], attempt)
        self.assertEqual(drain.read()["state"], "cancelling")
        self.assertEqual(wait.call_args.args, (attempt, "cancelled"))

    def test_profile_environment_and_progress(self):
        self.configure('printf "%s" "$NIXOS_DRAIN_PROFILE" > "' + str(self.root / "profile") + '"\necho waiting')
        attempt = drain.request("destroy")
        observed = []
        original = drain.update

        def record(*args, **kwargs):
            observed.append(kwargs)
            return original(*args, **kwargs)

        with patch.object(drain, "update", side_effect=record):
            self.work(attempt)
        self.assertEqual((self.root / "profile").read_text(), "destroy")
        self.assertIn({"progress": "waiting"}, observed)

    def test_failure_requires_explicit_cleanup(self):
        self.configure("exit 7")
        attempt = drain.request("upgrade")
        with self.assertRaisesRegex(RuntimeError, "status 7"):
            self.work(attempt)
        self.assertEqual(drain.read()["state"], "failed")
        self.assertEqual(drain.wait(attempt, "drained"), 1)
        with self.assertRaises(RuntimeError):
            drain.request("upgrade")
        drain.cancel()
        self.work(attempt, "cancelling")
        self.assertNotEqual(drain.request("destroy"), attempt)

    def test_timeout_kills_script_children_but_keeps_partial_drain(self):
        marker = self.root / "marker"
        late = self.root / "late"
        self.configure(f'touch "{marker}"\n(sleep 2; touch "{late}") &\nwait')
        attempt = drain.request("upgrade")
        with self.assertRaises(TimeoutError):
            self.work(attempt)
        self.assertEqual(drain.read()["state"], "timed-out")
        self.assertTrue(marker.exists())
        time.sleep(1.2)
        self.assertFalse(late.exists())

    def test_cancellation_cannot_be_overwritten_by_late_success(self):
        attempt = drain.request("upgrade")
        self.assertEqual(drain.cancel(), attempt)
        self.assertFalse(drain.update(attempt, "draining", drain.read()["unit"], state="drained"))
        self.work(attempt, "cancelling")
        self.assertEqual(drain.wait(attempt, "drained"), 1)
        self.assertEqual(drain.wait(attempt, "cancelled"), 0)

    def test_upgrade_timeout_recovers_registration_before_next_job_exits(self):
        marker = self.root / "maintenance"
        self.configure(f'touch "{marker}"; sleep 5', cancel=f'rm -f "{marker}"',
                       cancel_on_failure=True)
        attempt = drain.request("upgrade")
        with self.assertRaises(TimeoutError):
            self.work(attempt)
        self.assertEqual(drain.read()["state"], "cancelling")
        self.work(attempt, "cancelling")
        self.assertEqual(runner.gate(), 0)
        self.assertEqual(drain.wait(attempt, "drained"), 1)
        self.assertIn("timed out", drain.read()["failure"])
        self.assertNotEqual(drain.request("upgrade"), attempt)

    def test_automatic_cleanup_failure_does_not_loop(self):
        self.configure("exit 7", cancel="exit 8", cancel_on_failure=True)
        attempt = drain.request("upgrade")
        with self.assertRaises(RuntimeError):
            self.work(attempt)
        self.assertEqual(drain.read()["state"], "cancelling")
        with self.assertRaises(RuntimeError):
            self.work(attempt, "cancelling")
        self.assertEqual(drain.read()["state"], "failed")
        self.assertEqual(self.launch_mock.call_count, 2)

    def test_stale_failure_cannot_cancel_a_new_attempt(self):
        self.configure(cancel_on_failure=True)
        old = drain.request("upgrade")
        old_unit = drain.read()["unit"]
        drain.cancel()
        self.work(old, "cancelling")
        current = drain.request("destroy")
        drain.fail(old, "draining", old_unit, RuntimeError("late failure"))
        self.assertEqual(drain.read()["attempt"], current)
        self.assertEqual(drain.read()["state"], "draining")

    def test_automatic_cleanup_launch_failure_allows_manual_retry(self):
        self.configure(cancel_on_failure=True)
        attempt = drain.request("upgrade")
        with patch.object(drain, "launch", side_effect=RuntimeError("systemd unavailable")):
            drain.fail(attempt, "draining", drain.read()["unit"], TimeoutError("timed out"))
        self.assertEqual(drain.read()["state"], "failed")
        drain.cancel()
        self.work(attempt, "cancelling")
        self.assertEqual(drain.read()["state"], "cancelled")

    def test_cancellation_failure_can_be_retried(self):
        allowed = self.root / "allow-cleanup"
        self.configure(cancel=f'test -f "{allowed}"')
        attempt = drain.request("upgrade")
        drain.cancel()
        with self.assertRaises(RuntimeError):
            self.work(attempt, "cancelling")
        self.assertEqual(drain.read()["state"], "failed")
        original_unit = drain.read()["drainUnit"]
        failed_cleanup_unit = drain.read()["unit"]
        allowed.touch()
        drain.cancel()
        self.assertEqual(drain.read()["drainUnit"], original_unit)
        self.assertFalse(drain.update(attempt, "cancelling", failed_cleanup_unit, state="failed"))
        self.work(attempt, "cancelling")
        self.assertEqual(drain.read()["state"], "cancelled")

    def test_settings_are_frozen_for_cleanup_after_config_changes(self):
        marker = self.root / "cleanup"
        self.configure(cancel=f'touch "{marker}"')
        attempt = drain.request("upgrade")
        drain.CONFIG.write_text("{}")
        drain.cancel()
        self.work(attempt, "cancelling")
        self.assertTrue(marker.exists())

    def test_old_worker_cannot_change_new_attempt(self):
        old = drain.request("upgrade")
        drain.cancel()
        self.work(old, "cancelling")
        current = drain.request("destroy")
        self.assertFalse(drain.update(old, "draining", drain.read()["unit"], state="failed"))
        self.assertEqual(drain.read()["attempt"], current)

    def test_runner_gate_blocks_registration_and_cancel_only_starts(self):
        self.assertEqual(runner.gate(), 0)
        result = subprocess.CompletedProcess([], 0, "LoadState=loaded\nActiveState=inactive\nSubState=dead\n")
        with patch.object(runner.subprocess, "run", return_value=result) as commands:
            runner.drain(["runner.service"])
            self.assertEqual(runner.gate(), 1)
            runner.cancel(["runner.service"])
        self.assertEqual(runner.gate(), 0)
        calls = [call.args[0] for call in commands.call_args_list]
        self.assertIn(["systemctl", "start", "--no-block", "runner.service"], calls)
        self.assertFalse(any("stop" in call or "restart" in call for call in calls))

    def test_runner_waits_through_registration_job_and_cleanup(self):
        results = [subprocess.CompletedProcess([], 0, f"LoadState=loaded\nActiveState={state}\nSubState={state}\n")
                   for state in ("activating", "active", "deactivating", "inactive")]
        with patch.object(runner.subprocess, "run", side_effect=results) as commands, patch.object(runner.time, "sleep"):
            runner.drain(["runner.service"])
        self.assertEqual(commands.call_count, 4)

    def test_runner_missing_or_failed_unit_is_not_success(self):
        for properties in ("LoadState=not-found\n", "LoadState=loaded\nActiveState=failed\n"):
            with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, properties)):
                with self.assertRaises(RuntimeError):
                    runner.drain(["runner.service"])

    def test_runner_busy_uses_its_registration_and_boolean_api_status(self):
        token = self.root / "token"
        token.write_text("fixture-token\n")
        runner.CONFIG.write_text(json.dumps({
            "runner.service": {
                "name": "github-runner-01-enterprise-mahdtech",
                "url": "https://github.com/enterprises/MAHDTech",
                "tokenFile": str(token),
            },
        }))
        responses = [
            io.BytesIO(json.dumps({"runners": [{"name": "github-runner-01-enterprise-mahdtech",
                                               "status": "online", "busy": value}]}).encode())
            for value in (False, True)
        ]
        with patch.object(runner.urllib.request, "urlopen", side_effect=responses) as get:
            self.assertFalse(runner.busy(["runner.service"]))
            self.assertTrue(runner.busy(["runner.service"]))
        request = get.call_args_list[0].args[0]
        self.assertEqual(request.full_url,
                         "https://api.github.com/enterprises/MAHDTech/actions/runners?name=github-runner-01-enterprise-mahdtech&per_page=100")
        self.assertEqual(request.get_header("Authorization"), "Bearer fixture-token")

    def test_runner_busy_fails_closed_on_missing_or_offline_registration(self):
        token = self.root / "token"
        token.write_text("fixture-token\n")
        runner.CONFIG.write_text(json.dumps({
            "runner.service": {
                "name": "runner",
                "url": "https://github.com/enterprises/MAHDTech",
                "tokenFile": str(token),
            },
        }))
        for payload in ({"runners": []},
                        {"runners": [{"name": "runner", "status": "offline", "busy": False}]},
                        {"runners": [{"name": "runner", "status": "online", "busy": "false"}]}):
            with patch.object(runner.urllib.request, "urlopen",
                              return_value=io.BytesIO(json.dumps(payload).encode())):
                with self.assertRaises(RuntimeError):
                    runner.busy(["runner.service"])

    def test_status_json_output(self):
        output = io.StringIO()
        with patch("sys.stdout", output):
            drain.status(as_json=True)
        data = json.loads(output.getvalue())
        self.assertEqual(data.get("state"), "idle")

        attempt = drain.request("upgrade")
        self.work(attempt)
        output = io.StringIO()
        with patch("sys.stdout", output):
            drain.status(as_json=True)
        data = json.loads(output.getvalue())
        self.assertEqual(data.get("state"), "drained")
        self.assertEqual(data.get("profile"), "upgrade")
        self.assertIn("elapsed", data)
        self.assertIn("mode", data)

    def test_predicates_and_cli_status(self):
        with patch("sys.argv", ["nixos-drain", "is-idle"]):
            self.assertEqual(drain.main(), 0)
        with patch("sys.argv", ["nixos-drain", "is-drained"]):
            self.assertEqual(drain.main(), 1)

        attempt = drain.request("upgrade")
        self.work(attempt)

        with patch("sys.argv", ["nixos-drain", "is-idle"]):
            self.assertEqual(drain.main(), 1)
        with patch("sys.argv", ["nixos-drain", "is-drained"]):
            self.assertEqual(drain.main(), 0)
        with patch("sys.argv", ["nixos-drain", "is-drained", "--attempt", attempt]):
            self.assertEqual(drain.main(), 0)
        with patch("sys.argv", ["nixos-drain", "is-drained", "--attempt", "wrong-attempt"]):
            self.assertEqual(drain.main(), 1)

        output = io.StringIO()
        with patch("sys.argv", ["nixos-drain", "status", "--json"]), patch("sys.stdout", output):
            self.assertEqual(drain.main(), 0)
        data = json.loads(output.getvalue())
        self.assertEqual(data.get("state"), "drained")

    def test_runner_drain_deduplicates_repeated_waiting_logs(self):
        # 5 active states, then inactive.
        results = [subprocess.CompletedProcess([], 0, "LoadState=loaded\nActiveState=active\nSubState=running\n")
                   for _ in range(5)]
        results.append(subprocess.CompletedProcess([], 0, "LoadState=loaded\nActiveState=inactive\nSubState=dead\n"))

        output = io.StringIO()
        with patch.object(runner.subprocess, "run", side_effect=results), \
             patch.object(runner.time, "sleep"), \
             patch("sys.stdout", output):
            runner.drain(["runner.service"])

        lines = [line.strip() for line in output.getvalue().splitlines() if line.strip()]
        # "Waiting for runner.service (running)" should appear only ONCE, followed by "All runner registrations have retired"
        self.assertEqual(lines, [
            "Waiting for runner.service (running)",
            "All runner registrations have retired"
        ])


if __name__ == "__main__":
    unittest.main()
