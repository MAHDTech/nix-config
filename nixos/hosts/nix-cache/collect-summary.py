"""Publish upstream health, disk usage and rolling cache traffic metrics."""

import argparse
import collections
import concurrent.futures
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
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


def collect_storage(cache_path):
    total, used, available = shutil.disk_usage(cache_path)
    cache_bytes = None
    try:
        result = subprocess.run(
            ["du", "--summarize", "--block-size=1", "--", str(cache_path)],
            capture_output=True, text=True, check=True, timeout=30,
        )
        cache_bytes = int(result.stdout.split()[0])
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        pass
    return {
        "total_bytes": total, "used_bytes": used,
        "available_bytes": available, "cache_bytes": cache_bytes,
    }


def collect_traffic(log_path, previous, now):
    # Minute buckets bound state size; inode offsets avoid re-reading old logs.
    cutoff = int(now.timestamp() // 60) - 24 * 60
    buckets = {
        minute: collections.Counter(counts)
        for minute, counts in previous.get("buckets", {}).items()
        if int(minute) >= cutoff
    }
    cursors = {}
    for path in (log_path.with_name(log_path.name + ".1"), log_path):
        try:
            file = path.open("rb")
        except FileNotFoundError:
            continue
        with file:
            info = os.fstat(file.fileno())  # cspell:ignore fstat
            identity = f"{info.st_dev}:{info.st_ino}"
            if identity in cursors:
                continue
            offset = previous.get("cursors", {}).get(identity, 0)
            file.seek(offset if offset <= info.st_size else 0)
            while file.tell() < info.st_size:
                start = file.tell()
                line = file.readline()
                if not line.endswith(b"\n"):
                    file.seek(start)
                    break
                try:
                    record = json.loads(line)
                    minute = int(datetime.datetime.fromisoformat(record["time"]).timestamp() // 60)
                    status = int(record["status"])
                    size = max(0, int(record["bytes"]))
                    uri = record["uri"]
                    cache = record["cache"]
                    if not isinstance(uri, str) or not isinstance(cache, str):
                        continue
                except (ValueError, KeyError, TypeError, UnicodeError):
                    continue
                if minute < cutoff:
                    continue
                counts = buckets.setdefault(str(minute), collections.Counter())
                counts["requests"] += 1
                counts["errors"] += int(status >= 500)
                counts["not_found"] += int(status == 404)
                if "/nar/" in uri and status in (200, 206):
                    counts["archive_bytes"] += size
                    if cache in ("HIT", "STALE", "UPDATING", "REVALIDATED"):
                        counts["hit_bytes"] += size
            cursors[identity] = file.tell()
    if not cursors:
        raise FileNotFoundError(log_path)
    totals = collections.Counter({
        "requests": 0, "errors": 0, "not_found": 0,
        "archive_bytes": 0, "hit_bytes": 0,
    })
    for counts in buckets.values():
        totals.update(counts)
    return dict(totals), {"buckets": buckets, "cursors": cursors}


def write_json(destination, value, mode):
    # Rename within the same directory so readers never see a partial snapshot.
    with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as file:
        json.dump(value, file)
        temporary = file.name
    os.chmod(temporary, mode)
    os.replace(temporary, destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("upstreams", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--cache-path", type=Path, default=Path("/var/cache/nginx/nixpkgs"))
    parser.add_argument("--access-log", type=Path, default=Path("/var/log/nginx/nix-cache-access.log"))
    parser.add_argument("--limit-gib", type=int, required=True)
    parser.add_argument("--reserve-gib", type=int, required=True)
    args = parser.parse_args()
    upstreams = json.loads(args.upstreams.read_text())
    state_path = args.destination.with_name("stats-state.json")
    try:
        state = json.loads(state_path.read_text())
    except (FileNotFoundError, ValueError):
        state = {}
    now = datetime.datetime.now(datetime.timezone.utc)
    checked_at = now.isoformat()
    try:
        storage = collect_storage(args.cache_path)
        storage.update({
            "limit_bytes": args.limit_gib * 1024 ** 3,
            "reserve_bytes": args.reserve_gib * 1024 ** 3,
            "change_bytes": None,
            "previous_checked_at": state.get("storage_checked_at"),
        })
        if storage["cache_bytes"] is not None:
            if state.get("cache_bytes") is not None:
                storage["change_bytes"] = storage["cache_bytes"] - state["cache_bytes"]
            state.update(cache_bytes=storage["cache_bytes"], storage_checked_at=checked_at)
    except OSError:
        storage = None
    try:
        traffic, state["traffic"] = collect_traffic(args.access_log, state.get("traffic", {}), now)
    except OSError:
        traffic = None
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        endpoints = list(pool.map(probe, upstreams))
    snapshot = {
        "checked_at": checked_at, "endpoints": endpoints,
        "storage": storage, "traffic": traffic,
    }
    write_json(state_path, state, 0o600)
    write_json(args.destination, snapshot, 0o644)


if __name__ == "__main__":
    main()
