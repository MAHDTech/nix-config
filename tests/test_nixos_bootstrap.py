"""Exercise the release gate and reboot verification without invoking host Nix."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('worker', Path(__file__).resolve().parents[1] / 'nixos/system/config/services/nixos-bootstrap/worker.py')
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class BootstrapTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'config.json'
        self.config.write_text(json.dumps({'protocol': 1, 'hostname': 'guest', 'mode': 'controlled', 'vm_id': 'instance-a'}))
        for name, value in [('ROOT', self.root), ('CONFIG', self.config)]:
            p = patch.object(worker, name, value)
            p.start()
            self.addCleanup(p.stop)
        p = patch.object(worker.socket, 'gethostname', return_value='guest')
        p.start()
        self.addCleanup(p.stop)
        self.release = dict(protocol=1, hostname='guest', vm_id='instance-a', revision='a'*40, attempt='b'*32, timeout=60)

    def test_controlled_mode_never_releases_itself(self):
        worker.prepare()
        self.assertFalse(worker.read_record('release'))

    def test_instance_and_revision_validation(self):
        for update in [{'vm_id': 'instance-b'}, {'revision': 'trunk'}, {'hostname': 'other'}, {'timeout': True}]:
            with self.subTest(update=update), self.assertRaises(ValueError):
                worker.validate_release(self.release | update)

    def test_cannot_replace_active_or_completed_attempt(self):
        with patch.object(worker, 'active', return_value=True), self.assertRaises(ValueError):
            worker.release(self.release)
        worker.write_record('complete', {'stage': 'complete'})
        with self.assertRaises(ValueError):
            worker.release(self.release)

    def test_automatic_requires_explicit_pinned_configuration(self):
        cfg = json.loads(self.config.read_text()) | {'mode': 'automatic', 'revision': 'a'*40}
        self.config.write_text(json.dumps(cfg))
        with patch.object(worker, 'active', return_value=False), patch.object(worker.subprocess, 'run'):
            worker.prepare()
        self.assertEqual(worker.read_record('release')['revision'], 'a'*40)

    def test_completion_requires_new_boot_and_exact_system(self):
        worker.write_record('status', self.release | {'stage': 'booting', 'boot_id': 'old', 'system': '/nix/store/target'})
        with patch.object(worker, 'boot_id', return_value='old'), self.assertRaises(ValueError):
            worker.complete(self.release)
        with patch.object(worker, 'boot_id', return_value='new'), patch.object(worker.os.path, 'realpath', return_value='/nix/store/target'):
            worker.complete(self.release)
        self.assertEqual(worker.read_record('complete')['stage'], 'complete')

    def test_cloud_init_failure_does_not_consume_release(self):
        worker.write_record('release', self.release)
        with patch.object(worker.subprocess, 'run') as run:
            run.return_value.returncode = 1
            with self.assertRaises(ValueError):
                worker.build()
        self.assertEqual(worker.read_record('release'), self.release)

    def test_build_orders_boot_activation_before_reboot(self):
        worker.write_record('release', self.release)
        with patch.object(worker.subprocess, 'run') as cloud, patch.object(worker, 'run_command') as run:
            cloud.return_value.returncode = 0
            cloud.return_value.stdout = '{"status":"done"}'
            worker.build()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[0][0:2], ['nix', 'build'])
        self.assertIn('--no-update-lock-file', commands[0])
        self.assertEqual(commands[2][-1], 'boot')
        self.assertEqual(commands[3], ['systemctl', 'reboot', '--no-block'])
        self.assertEqual(worker.read_record('status')['stage'], 'booting')
        self.assertFalse(worker.read_record('complete'))

    def test_timeout_preserves_failure_and_never_reboots(self):
        worker.write_record('release', self.release)
        with patch.object(worker.subprocess, 'run') as cloud, patch.object(worker, 'run_command', side_effect=TimeoutError) as run:
            cloud.return_value.returncode = 0
            cloud.return_value.stdout = '{"status":"done"}'
            with self.assertRaises(TimeoutError):
                worker.build()
        run.assert_called_once()
        self.assertEqual(worker.read_record('status')['stage'], 'failed')


if __name__ == '__main__':
    unittest.main()
