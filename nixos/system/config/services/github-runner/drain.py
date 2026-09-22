"""Retire ephemeral registrations without stopping a runner that may own a job."""

from contextlib import contextmanager
import fcntl
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path("/run/nixos-drain/github-runners")


@contextmanager
def locked():
    with (ROOT / "lock").open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def gate():
    # ExecCondition runs before registration. An already admitted start may finish one job.
    with locked():
        return 1 if (ROOT / "maintenance").exists() else 0


def drain(units):
    with locked():
        (ROOT / "maintenance").touch()
    while True:
        waiting = []
        for unit in units:
            result = subprocess.run(
                ["systemctl", "show", unit, "--property=LoadState,ActiveState,SubState"],
                check=True, text=True, capture_output=True,
            )
            properties = dict(line.split("=", 1) for line in result.stdout.splitlines())
            if properties.get("LoadState") != "loaded":
                raise RuntimeError(f"Cannot inspect {unit}; refusing to report drained")
            active = properties.get("ActiveState")
            if active == "failed":
                raise RuntimeError(f"{unit} failed; inspect the runner journal before retrying")
            if active != "inactive":
                waiting.append(f"{unit} ({properties.get('SubState', active)})")
        if not waiting:
            print("All runner registrations have retired", flush=True)
            return
        print("Waiting for " + ", ".join(waiting), flush=True)
        time.sleep(2)


def cancel(units):
    with locked():
        (ROOT / "maintenance").unlink(missing_ok=True)
    for unit in units:
        subprocess.run(["systemctl", "reset-failed", unit], check=True)
        # start leaves an existing worker untouched; restart would cancel its job.
        subprocess.run(["systemctl", "start", "--no-block", unit], check=True)
    print("Runner registration enabled", flush=True)


if __name__ == "__main__":
    try:
        command, *units = sys.argv[1:]
        if command == "gate":
            sys.exit(gate())
        if command == "drain":
            drain(units)
        elif command == "cancel":
            cancel(units)
        else:
            raise RuntimeError(f"Unknown command: {command}")
    except Exception as error:
        print(f"github-runner-drain: {error}", file=sys.stderr)
        sys.exit(255)
