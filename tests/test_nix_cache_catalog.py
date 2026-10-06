"""Check cache catalog parsing, package names and eviction handling."""

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "cache_catalog", Path(__file__).resolve().parents[1] / "nixos/hosts/nix-cache/collect-catalog.py",
)
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


class CatalogTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.upstreams = [
            {"name": "nixpkgs", "host": "cache.nixos.org", "prefix": ""},
            {"name": "devenv", "host": "devenv.cachix.org", "prefix": "/devenv"},
        ]

    def cache(self, uri, body=b"archive", upstream=0, status=200, length=None):
        source = self.upstreams[upstream]
        key = (source["host"] + source["prefix"] + uri).encode()
        digest = hashlib.md5(key, usedforsecurity=False).hexdigest()
        path = self.root / digest[-1] / digest[-3:-1] / digest
        path.parent.mkdir(parents=True, exist_ok=True)
        prefix = b"\0" * 336 + b"\nKEY: " + key + b"\n"
        headers = f"HTTP/1.1 {status} Test\r\nContent-Length: {len(body) if length is None else length}\r\n\r\n".encode()
        path.write_bytes(prefix + headers + body)
        return path

    def test_metadata_names_archives_without_crossing_upstreams(self):
        self.cache("/" + "a" * 32 + ".narinfo", (
            "StorePath: /nix/store/" + "b" * 32 + "-hello-2.12\nURL: nar/test.nar.xz\n"
        ).encode())
        self.cache("/nar/test.nar.xz")
        self.cache("/nar/test.nar.xz", upstream=1)
        entries = catalog.collect_catalog(self.root, self.upstreams)["entries"]
        by_url = {entry["url"]: entry for entry in entries}
        self.assertEqual(by_url["/nar/test.nar.xz"]["name"], "hello-2.12")
        self.assertEqual(by_url["/devenv/nar/test.nar.xz"]["name"], "test.nar.xz")
        self.assertEqual(by_url["/nar/test.nar.xz"]["size_bytes"], 7)
        self.assertEqual(len(entries), 3)
        self.assertNotIn("archive_uri", str(entries))

    def test_incomplete_foreign_query_and_error_entries_are_skipped(self):
        self.cache("/nar/incomplete", length=999)
        self.cache("/nar/error", status=404)
        self.cache("/nar/private?token=secret")
        self.cache("/nix-cache-info")
        path = self.cache("/nar/bad-key")
        path.write_bytes(path.read_bytes().replace(b"cache.nixos.org", b"alien.nixos.org"))
        self.assertEqual(catalog.collect_catalog(self.root, self.upstreams)["entries"], [])

    def test_eviction_and_corrupt_metadata_do_not_break_scan(self):
        path = self.cache("/nar/evicted")
        path.unlink()
        self.cache("/" + "a" * 32 + ".narinfo", b"\xff")
        self.cache("/nar/present")
        snapshot = catalog.collect_catalog(self.root, self.upstreams)
        self.assertEqual(len(snapshot["entries"]), 1)
        self.assertEqual(snapshot["entries"][0]["url"], "/nar/present")
        self.assertIsNone(catalog.read_entry(path, self.upstreams))

    def test_scan_limits_are_explicit_and_symlinks_are_not_followed(self):
        path = self.cache("/nar/real")
        (self.root / ("c" * 32)).symlink_to(path)
        self.assertEqual(len(catalog.collect_catalog(self.root, self.upstreams)["entries"]), 1)
        self.assertTrue(catalog.collect_catalog(self.root, self.upstreams, max_files=0)["truncated"])
        self.assertTrue(catalog.collect_catalog(self.root, self.upstreams, budget_seconds=0)["truncated"])


if __name__ == "__main__":
    unittest.main()
