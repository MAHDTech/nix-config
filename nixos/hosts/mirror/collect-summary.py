"""Publish mirror filesystem capacity and content size."""

import argparse
import datetime
from pathlib import Path
import sys

_COLLECTOR_DIR = Path(__file__).resolve().parents[2] / "system/config/services/collector"
if str(_COLLECTOR_DIR) not in sys.path and _COLLECTOR_DIR.is_dir():
    sys.path.insert(0, str(_COLLECTOR_DIR))

from common import collect_disk_usage, write_json_atomic  # noqa: E402


def collect_storage(root):
    total, used, available, content_bytes = collect_disk_usage(root)
    return {
        "total_bytes": total,
        "used_bytes": used,
        "available_bytes": available,
        "content_bytes": content_bytes,
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
    write_json_atomic(args.destination, snapshot, 0o644)


if __name__ == "__main__":
    main()
