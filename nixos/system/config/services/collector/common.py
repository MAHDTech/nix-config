"""Shared disk-usage and atomic JSON helpers for host summary collectors."""

import json
import os
import shutil
import subprocess
import tempfile


def collect_disk_usage(root, timeout=30):
    """Return (total, used, available, content_bytes) for a filesystem root."""
    total, used, available = shutil.disk_usage(root)
    content_bytes = None
    try:
        result = subprocess.run(
            ["du", "--summarize", "--block-size=1", "--", str(root)],
            capture_output=True,
            text=True,
            check=True,
            timeout=timeout,
        )
        content_bytes = int(result.stdout.split()[0])
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        pass
    return total, used, available, content_bytes


def write_json_atomic(destination, value, mode=0o644):
    """Write JSON to a sibling temporary file and atomically replace destination."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=destination.parent, delete=False
        ) as file:
            temporary = file.name
            json.dump(value, file)
        os.chmod(temporary, mode)
        os.replace(temporary, destination)
    except BaseException:
        if temporary is not None:
            try:
                os.unlink(temporary)
            except OSError:
                pass
        raise
