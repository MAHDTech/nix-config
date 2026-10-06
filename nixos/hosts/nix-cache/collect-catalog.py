# cspell:ignore fstat
"""Index complete nginx cache entries without publishing their internal headers."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import tempfile
import time


def read_entry(path, upstreams):
    if not re.fullmatch(r"[0-9a-f]{32}", path.name):
        return None
    try:
        with path.open("rb") as file:
            info = os.fstat(file.fileno())
            if not stat.S_ISREG(info.st_mode):
                return None
            prefix = file.read(8192)
            marker = prefix.find(b"\nKEY: ")
            if marker < 0:
                return None
            key_end = prefix.find(b"\n", marker + 6)
            if key_end < 0:
                return None
            key = prefix[marker + 6:key_end]
            # nginx names cache files with the MD5 of the configured cache key.
            if hashlib.md5(key, usedforsecurity=False).hexdigest() != path.name:
                return None
            key = key.decode("ascii")
            upstream = next((item for item in upstreams if key.startswith(item["host"] + "/")), None)
            if upstream is None:
                return None
            url = key[len(upstream["host"]):]
            if not url.startswith(upstream["prefix"] + "/"):
                return None
            uri = url[len(upstream["prefix"]):]
            if "?" in uri or not re.fullmatch(r"/(?:[0-9a-z]{32}\.narinfo|nar/[A-Za-z0-9._-]+)", uri):
                return None
            header_start = key_end + 1
            header_end = prefix.find(b"\r\n\r\n", header_start)
            if header_end < 0:
                prefix += file.read(65536 - len(prefix))
                header_end = prefix.find(b"\r\n\r\n", header_start)
            if header_end < 0 or not re.match(rb"HTTP/1\.[01] 200(?: |\r)", prefix[header_start:]):
                return None
            body_start = header_end + 4
            headers = prefix[header_start:header_end].decode("iso-8859-1")
            fields = {}
            for line in headers.split("\r\n")[1:]:
                name, separator, value = line.partition(":")
                if separator:
                    fields[name.lower()] = value.strip()
            size = info.st_size - body_start
            length = fields.get("content-length")
            if size < 0 or (length is not None and size != int(length)):
                return None
            entry = {
                "upstream": upstream["name"], "uri": uri,
                "url": url,
                "name": uri.rsplit("/", 1)[-1], "size_bytes": size,
            }
            if uri.endswith(".narinfo"):
                if size > 16384 or fields.get("content-encoding", "identity") != "identity":
                    return None
                file.seek(body_start)
                metadata = {}
                for line in file.read(size).decode("utf-8").splitlines():
                    name, separator, value = line.partition(":")
                    if separator:
                        metadata[name] = value.strip()
                store_path = metadata.get("StorePath", "")
                if re.fullmatch(r"/nix/store/[0-9a-z]{32}-.+", store_path):
                    entry["name"] = store_path.split("/", 3)[-1][33:]
                entry["archive_uri"] = "/" + metadata.get("URL", "").lstrip("/")
            return entry
    except (OSError, UnicodeError, ValueError):
        return None


def collect_catalog(root, upstreams, max_files=100000, budget_seconds=90):
    if not root.is_dir():
        raise FileNotFoundError(root)
    entries = {}
    names = {}
    scanned = 0
    truncated = False
    deadline = time.monotonic() + budget_seconds
    for directory, _, files in os.walk(root):
        for filename in files:
            if scanned >= max_files or time.monotonic() >= deadline:
                truncated = True
                break
            scanned += 1
            path = Path(directory) / filename
            if path.is_symlink():
                continue
            entry = read_entry(path, upstreams)
            if entry is None:
                continue
            if entry["uri"].endswith(".narinfo"):
                names[(entry["upstream"], entry.pop("archive_uri"))] = entry["name"]
            entries[(entry["upstream"], entry["uri"])] = entry
        if truncated:
            break
    for key, entry in entries.items():
        if key in names:
            entry["name"] = names[key]
        entry["kind"] = "metadata" if entry.pop("uri").endswith(".narinfo") else "archive"
    return {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "truncated": truncated,
        "entries": sorted(entries.values(), key=lambda item: (item["upstream"], item["name"], item["url"])),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("upstreams", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--cache-path", type=Path, default=Path("/var/cache/nginx/nixpkgs"))
    args = parser.parse_args()
    snapshot = collect_catalog(args.cache_path, json.loads(args.upstreams.read_text()))
    with tempfile.NamedTemporaryFile(mode="w", dir=args.destination.parent, delete=False) as file:
        json.dump(snapshot, file)
        temporary = file.name
    os.chmod(temporary, 0o644)
    os.replace(temporary, args.destination)


if __name__ == "__main__":
    main()
