"""Inspect and retire ephemeral registrations without interrupting jobs."""

from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.parse
import urllib.request

ROOT = Path("/run/nixos-drain/github-runners")
CONFIG = Path(os.environ.get("GITHUB_RUNNER_DRAIN_CONFIG", "/etc/github-runner-drain.json"))


@contextmanager
def locked():
    with (ROOT / "lock").open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def gate():
    # ExecCondition runs before registration. An already admitted start may finish one job.
    with locked():
        return 1 if (ROOT / "maintenance").exists() else 0


def busy(units):
    """Return whether any configured runner is executing a job on GitHub."""
    config = json.loads(CONFIG.read_text())
    states = []
    for unit in units:
        runner = config[unit]
        name = runner["name"]
        url = urllib.parse.urlsplit(runner["url"])
        parts = url.path.strip("/").split("/")
        if url.scheme != "https" or url.netloc != "github.com":
            raise RuntimeError(f"Unsupported registration URL for {unit}")
        if len(parts) == 2 and parts[0] == "enterprises":
            endpoint = f"/enterprises/{urllib.parse.quote(parts[1], safe='')}/actions/runners"
        elif len(parts) == 1:
            endpoint = f"/orgs/{urllib.parse.quote(parts[0], safe='')}/actions/runners"
        elif len(parts) == 2:
            endpoint = "/repos/{}/{}/actions/runners".format(
                *(urllib.parse.quote(part, safe="") for part in parts)
            )
        else:
            raise RuntimeError(f"Unsupported registration URL for {unit}")
        token = Path(runner["tokenFile"]).read_text().strip()
        if not token:
            raise RuntimeError(f"Empty GitHub token for {unit}")
        query = urllib.parse.urlencode({"name": name, "per_page": 100})
        request = urllib.request.Request(
            f"https://api.github.com{endpoint}?{query}",
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "User-Agent": "nixos-drain",
                "X-GitHub-Api-Version": "2026-03-10",
            },
        )
        with urllib.request.urlopen(request, timeout=10) as response:
            registrations = json.load(response)["runners"]
        matches = [registration for registration in registrations if registration["name"] == name]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one GitHub registration for {unit}; found {len(matches)}")
        registration = matches[0]
        if registration.get("status") != "online" or type(registration.get("busy")) is not bool:
            raise RuntimeError(f"GitHub runner status is unavailable for {unit}")
        states.append(registration["busy"])
    return any(states)


def drain(units):
    with locked():
        (ROOT / "maintenance").touch()
    last_waiting = None
    last_logged = 0.0
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
        now = time.monotonic()
        if waiting != last_waiting or (now - last_logged) >= 30:
            print("Waiting for " + ", ".join(waiting), flush=True)
            last_waiting = list(waiting)
            last_logged = now
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
        if command == "busy":
            print("true" if busy(units) else "false")
            sys.exit(0)
        if command == "drain":
            drain(units)
        elif command == "cancel":
            cancel(units)
        else:
            raise RuntimeError(f"Unknown command: {command}")
    except Exception as error:
        print(f"github-runner-drain: {error}", file=sys.stderr)
        sys.exit(255)
