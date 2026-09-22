"""Named, boot-scoped drains with systemd-owned execution and explicit cleanup."""

# cspell:ignore PYTHONUNBUFFERED geteuid

import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path("/run/nixos-drain")
CONFIG = Path("/etc/nixos-drain/config.json")


@contextmanager
def locked():
    with (ROOT / "lock").open("a") as handle:
        os.chmod(handle.name, 0o600)
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def read():
    try:
        return json.loads((ROOT / "status.json").read_text())
    except FileNotFoundError:
        return {"state": "idle"}


def save(state):
    temporary = ROOT / "status.tmp"
    temporary.write_text(json.dumps(state) + "\n")
    temporary.chmod(0o644)
    temporary.replace(ROOT / "status.json")


def update(attempt, phase, unit, **changes):
    with locked():
        state = read()
        if state.get("attempt") != attempt or state["state"] != phase or state.get("unit") != unit:
            return False
        state.update(changes)
        save(state)
        return True


def launch(state, phase):
    executable = os.environ["NIXOS_DRAIN_EXECUTABLE"]
    unit = f"nixos-drain-{uuid.uuid4().hex}"
    state["unit"] = unit
    save(state)
    subprocess.run(
        [
            "systemd-run", "--quiet", "--collect", f"--unit={unit}",
            "--property=Type=exec", "--property=TimeoutStopSec=10s",
            "--property=KillMode=control-group",
            f"--property=ExecStopPost={executable} _stopped {state['attempt']} {phase} {unit}",
            executable, "_worker", state["attempt"], phase, unit,
        ],
        check=True,
    )


def request(profile):
    profiles = json.loads(CONFIG.read_text())
    if profile not in profiles:
        raise RuntimeError(f"Unknown profile: {profile}")
    with locked():
        state = read()
        if state["state"] not in ("idle", "cancelled"):
            if state.get("profile") == profile and state["state"] in ("draining", "drained"):
                return state["attempt"]
            raise RuntimeError("An existing drain needs attention; inspect status and cancel it first.")
        state = {
            "attempt": uuid.uuid4().hex,
            "profile": profile,
            "state": "draining",
            "started": time.time(),
            "progress": "Starting drain",
            "settings": profiles[profile],
        }
        try:
            launch(state, "draining")
        except Exception:
            state.update(state="failed", progress="Could not start drain worker", finished=time.time())
            save(state)
            raise
        return state["attempt"]


def cancel():
    with locked():
        state = read()
        if state["state"] in ("idle", "cancelled"):
            return None
        if state["state"] == "cancelling":
            return state["attempt"]
        # Keep the original unit across cancellation retries after a cleanup failure.
        state.setdefault("drainUnit", state["unit"])
        state.update(state="cancelling", progress="Stopping drain worker and undoing drain")
        state.pop("finished", None)
        try:
            launch(state, "cancelling")
        except Exception:
            state.update(state="failed", progress="Could not start cancellation worker", finished=time.time())
            save(state)
            raise
        return state["attempt"]


def run_script(state, phase):
    settings = state["settings"]
    script = settings["script" if phase == "draining" else "cancelScript"]
    deadline = time.monotonic() + settings["timeoutSeconds"]
    environment = dict(os.environ, NIXOS_DRAIN_PROFILE=state["profile"], PYTHONUNBUFFERED="1")
    process = subprocess.Popen(
        [script], env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    pending = b""
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while selector.get_map():
                if time.monotonic() >= deadline:
                    raise TimeoutError("Profile script timed out; cancel to undo partial drain actions")
                for key, _ in selector.select(timeout=0.2):
                    chunk = os.read(key.fileobj.fileno(), 4096)
                    if not chunk:
                        selector.unregister(key.fileobj)
                    pending += chunk
                    while b"\n" in pending or (not chunk and pending):
                        line, _, pending = pending.partition(b"\n")
                        message = line.decode(errors="replace")[-1000:]
                        print(message, flush=True)
                        update(state["attempt"], phase, state["unit"], progress=message)
                    # Bound memory even if a command emits a line without a newline.
                    pending = pending[-8192:]
        result = process.wait(timeout=max(0.01, deadline - time.monotonic()))
        if result:
            raise RuntimeError(f"Profile script exited with status {result}; inspect the journal")
    finally:
        # Only this script's process group is affected, never application service units.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        process.stdout.close()


def worker(attempt, phase, unit):
    with locked():
        state = read()
        if state.get("attempt") != attempt or state["state"] != phase or state.get("unit") != unit:
            return
    try:
        if phase == "cancelling":
            # A collected unit is already stopped. Other stop failures must block cleanup.
            result = subprocess.run(
                ["systemctl", "show", state["drainUnit"], "--property=LoadState", "--value"],
                check=True, text=True, capture_output=True,
            )
            if result.stdout.strip() != "not-found":
                subprocess.run(["systemctl", "stop", state["drainUnit"]], check=True)
        subprocess.run(
            ["wall", f"nixos-drain: {state['profile']} profile {phase}"],
            check=False, timeout=5,
        )
        run_script(state, phase)
        update(
            attempt, phase, unit, state="drained" if phase == "draining" else "cancelled",
            progress="Notification only; no application drain configured"
            if phase == "draining" and state["settings"]["notificationOnly"]
            else "Drain complete" if phase == "draining" else "Drain cancelled",
            finished=time.time(),
        )
    except Exception as error:
        update(
            attempt, phase, unit,
            state="timed-out" if isinstance(error, (TimeoutError, subprocess.TimeoutExpired)) else "failed",
            progress=str(error), finished=time.time(),
        )
        raise


def wait(attempt, success):
    if attempt is None:
        return 0
    while True:
        state = read()
        if state.get("attempt") != attempt:
            raise RuntimeError("Drain attempt was replaced")
        if state["state"] == success:
            return 0
        if state["state"] not in ("draining", "cancelling"):
            print(state["progress"], file=sys.stderr)
            return 1
        time.sleep(0.2)


def status():
    state = read()
    print(f"State:     {state['state']}")
    if "profile" in state:
        elapsed = int(state.get("finished", time.time()) - state["started"])
        print(f"Profile:   {state['profile']}")
        print(f"Elapsed:   {elapsed}s")
        print(f"Timeout:   {state['settings']['timeoutSeconds']}s")
        print(f"Mode:      {'notification-only' if state['settings']['notificationOnly'] else 'application drain'}")
        print(f"Progress:  {state['progress']}")
        print(f"Logs:      journalctl -u {state['unit']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    commands.add_parser("cancel")
    drain = commands.add_parser("drain")
    drain.add_argument("--profile", required=True)
    for name in ("_worker", "_stopped"):
        internal = commands.add_parser(name, help=argparse.SUPPRESS)
        internal.add_argument("attempt")
        internal.add_argument("phase", choices=("draining", "cancelling"))
        internal.add_argument("unit")
    args = parser.parse_args()
    if args.command == "status":
        status()
        return 0
    if os.geteuid() != 0:
        raise RuntimeError("Run this command as root (sudo)")
    if args.command == "drain":
        return wait(request(args.profile), "drained")
    if args.command == "cancel":
        return wait(cancel(), "cancelled")
    if args.command == "_worker":
        worker(args.attempt, args.phase, args.unit)
    else:
        update(args.attempt, args.phase, args.unit, state="failed", progress="Worker stopped unexpectedly; cancel to clean up", finished=time.time())
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("Detached; the drain continues. Use nixos-drain status or cancel.", file=sys.stderr)
        sys.exit(130)
    except Exception as error:
        print(f"nixos-drain: {error}", file=sys.stderr)
        sys.exit(1)
