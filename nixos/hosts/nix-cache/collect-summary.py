"""Probe upstream metadata without reading the local cache or access logs."""

import concurrent.futures
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def probe(upstream):
    result = {"name": upstream["name"], "status": "unavailable", "priority": None}
    started = time.monotonic()
    try:
        response = subprocess.run(
            [
                "curl", "--silent", "--fail", "--proto", "=https",
                "--connect-timeout", "5", "--max-time", "10",
                "--max-filesize", "16384",
                f'https://{upstream["host"]}/nix-cache-info',
            ],
            capture_output=True, check=True, timeout=12,
        )
        fields = {}
        for line in response.stdout.decode("utf-8").splitlines():
            key, separator, value = line.partition(":")
            if separator:
                fields[key.strip()] = value.strip()
        if fields.get("StoreDir") != "/nix/store":
            result["status"] = "invalid"
        else:
            priority = fields.get("Priority")
            if priority is not None:
                result["priority"] = int(priority)
            result["status"] = "reachable"
    except (subprocess.SubprocessError, UnicodeError, ValueError):
        pass
    result["duration_ms"] = round((time.monotonic() - started) * 1000)
    return result


def main():
    upstreams = json.loads(Path(sys.argv[1]).read_text())
    destination = Path(sys.argv[2])
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        endpoints = list(pool.map(probe, upstreams))
    snapshot = {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "endpoints": endpoints,
    }
    # Rename within the same directory so readers never see a partial snapshot.
    with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as file:
        json.dump(snapshot, file)
        temporary = file.name
    os.chmod(temporary, 0o644)
    os.replace(temporary, destination)


if __name__ == "__main__":
    main()
