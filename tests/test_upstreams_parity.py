"""Verify flake.nix nixConfig stays aligned with nix-cache upstreams.json."""

import json
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[1]


class UpstreamsParityTest(unittest.TestCase):
    def test_flake_nix_config_matches_upstreams_json(self):
        upstreams = json.loads(
            (REPO / "nixos/system/config/services/nix-cache/upstreams.json").read_text()
        )
        flake = (REPO / "flake.nix").read_text()

        sub_match = re.search(r"extra-substituters\s*=\s*''(.*?)''\s*;", flake, re.S)
        key_match = re.search(r'extra-trusted-public-keys\s*=\s*"(.*?)"\s*;', flake, re.S)
        self.assertIsNotNone(sub_match, "extra-substituters block not found in flake.nix")
        self.assertIsNotNone(key_match, "extra-trusted-public-keys block not found in flake.nix")

        substituters = sub_match.group(1).split()
        keys = set(key_match.group(1).split())

        for url in substituters:
            self.assertFalse(
                url.endswith("/"),
                f"Trailing slash in flake.nix substituter: {url}",
            )

        expected_local = [
            f"https://nix-cache.slopageddon.app{item['prefix']}?priority=10"
            for item in upstreams
        ]
        expected_upstream = [f"https://{item['host']}" for item in upstreams]
        self.assertEqual(
            set(substituters),
            set(expected_local + expected_upstream),
            "flake.nix extra-substituters drifted from upstreams.json",
        )
        for item in upstreams:
            self.assertIn(
                item["publicKey"],
                keys,
                f"Missing public key for {item['name']} in flake.nix",
            )


if __name__ == "__main__":
    unittest.main()
