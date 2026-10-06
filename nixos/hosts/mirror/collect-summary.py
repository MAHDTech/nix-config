"""Publish mirror filesystem capacity and content size."""

import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def collect_storage(root):
    total, used, available = shutil.disk_usage(root)
    content_bytes = None
    try:
        result = subprocess.run(
            ["du", "--summarize", "--block-size=1", "--", str(root)],
            capture_output=True, text=True, check=True, timeout=30,
        )
        content_bytes = int(result.stdout.split()[0])
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        pass
    return {
        "total_bytes": total, "used_bytes": used,
        "available_bytes": available, "content_bytes": content_bytes,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    snapshot = {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "storage": collect_storage(args.root),
    }
    with tempfile.NamedTemporaryFile(mode="w", dir=args.destination.parent, delete=False) as file:
        json.dump(snapshot, file)
        temporary = file.name
    os.chmod(temporary, 0o644)
    os.replace(temporary, args.destination)


if __name__ == "__main__":
    main()
