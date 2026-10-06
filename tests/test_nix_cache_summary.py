"""Check rolling cache metrics against real log appends and rotation."""

import datetime
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    'cache_summary',
    Path(__file__).resolve().parents[1] / 'nixos/hosts/nix-cache/collect-summary.py',
)
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)


class CacheSummaryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.log = Path(self.tmp.name) / 'access.log'
        self.now = datetime.datetime(2026, 10, 6, 1, 30, tzinfo=datetime.timezone.utc)

    def record(self, cache='HIT', size=100, status=200, uri='/nar/test.nar.zst', age=0):
        return json.dumps({
            'time': (self.now - datetime.timedelta(seconds=age)).isoformat(),
            'uri': uri, 'status': status, 'bytes': size, 'cache': cache,
        }) + '\n'

    def test_rolling_window_and_byte_hit_rate(self):
        self.log.write_text(
            self.record(size=300) + self.record(cache='MISS')
            + self.record(cache='STALE', size=100)
            + self.record(status=404, uri='/missing.narinfo')
            + self.record(status=504, uri='/failed.narinfo')
            + self.record(age=25 * 3600) + 'legacy log line\n'
        )
        traffic, state = summary.collect_traffic(self.log, {}, self.now)
        self.assertEqual(traffic['requests'], 5)
        self.assertEqual(traffic['archive_bytes'], 500)
        self.assertEqual(traffic['hit_bytes'], 400)
        self.assertEqual(traffic['errors'], 1)
        self.assertEqual(traffic['not_found'], 1)
        again, _ = summary.collect_traffic(self.log, state, self.now)
        self.assertEqual(again, traffic)
        expired, _ = summary.collect_traffic(
            self.log, state, self.now + datetime.timedelta(hours=25),
        )
        self.assertEqual(expired['requests'], 0)

    def test_rotation_and_partial_records_are_not_double_counted(self):
        self.log.write_text(self.record())
        _, state = summary.collect_traffic(self.log, {}, self.now)
        with self.log.open('a') as file:
            file.write(self.record(cache='MISS', size=200))
        self.log.rename(self.log.with_name('access.log.1'))
        line = self.record(size=400)
        self.log.write_text(line[:20])
        traffic, state = summary.collect_traffic(self.log, state, self.now)
        self.assertEqual(traffic['archive_bytes'], 300)
        with self.log.open('a') as file:
            file.write(line[20:])
        traffic, state = summary.collect_traffic(self.log, state, self.now)
        self.assertEqual(traffic['archive_bytes'], 700)
        again, _ = summary.collect_traffic(self.log, state, self.now)
        self.assertEqual(again, traffic)

    def test_missing_logs_are_unavailable_not_zero_traffic(self):
        with self.assertRaises(FileNotFoundError):
            summary.collect_traffic(self.log, {}, self.now)

    def test_empty_log_and_truncation(self):
        self.log.touch()
        traffic, _ = summary.collect_traffic(self.log, {}, self.now)
        self.assertEqual(traffic['requests'], 0)
        self.log.write_text(self.record() * 2)
        _, state = summary.collect_traffic(self.log, {}, self.now)
        self.log.write_text(self.record(size=200, status=206))
        traffic, _ = summary.collect_traffic(self.log, state, self.now)
        self.assertEqual(traffic['archive_bytes'], 400)

    def test_storage_reports_available_space_and_measurement_failure(self):
        with mock.patch.object(summary.shutil, 'disk_usage', return_value=(1000, 700, 200)):
            with mock.patch.object(summary.subprocess, 'run') as run:
                run.return_value.stdout = '512\t/cache\n'
                storage = summary.collect_storage(Path(self.tmp.name))
            self.assertEqual(storage['available_bytes'], 200)
            self.assertEqual(storage['cache_bytes'], 512)
            with mock.patch.object(summary.subprocess, 'run', side_effect=OSError):
                storage = summary.collect_storage(Path(self.tmp.name))
            self.assertIsNone(storage['cache_bytes'])
            self.assertEqual(storage['available_bytes'], 200)

    def test_snapshot_persists_offsets_and_cache_growth(self):
        root = Path(self.tmp.name)
        catalog = root / 'upstreams.json'
        catalog.write_text('[]')
        cache = root / 'cache'
        cache.mkdir()
        self.log.write_text(self.record())
        destination = root / 'summary.json'
        argv = [
            'collect-summary', str(catalog), str(destination),
            '--cache-path', str(cache), '--access-log', str(self.log),
            '--limit-gib', '750', '--reserve-gib', '100',
        ]
        with mock.patch('sys.argv', argv), mock.patch.object(summary, 'datetime') as clock:
            clock.datetime.now.return_value = self.now
            clock.datetime.fromisoformat = datetime.datetime.fromisoformat
            summary.main()
            first = json.loads(destination.read_text())
            self.assertEqual(first['traffic']['requests'], 1)
            self.assertIsNone(first['storage']['change_bytes'])
            (cache / 'archive').write_bytes(b'x' * 8192)
            summary.main()
            second = json.loads(destination.read_text())
            self.assertEqual(second['traffic']['requests'], 1)
            self.assertGreater(second['storage']['change_bytes'], 0)
            self.assertEqual(destination.stat().st_mode & 0o777, 0o644)
            self.assertEqual((root / 'stats-state.json').stat().st_mode & 0o777, 0o600)


if __name__ == '__main__':
    unittest.main()
