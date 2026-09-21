#!/usr/bin/env python3
"""Generic guest-side provisioning protocol; no application or secret handling."""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
import uuid

ROOT = Path("/var/lib/nixos-bootstrap")
REPOSITORY = "github:MAHDTech/nix-config"
CONFIG = Path("/etc/nixos-bootstrap.json")


def configuration() -> dict:
    """Cloud-init supplies data, never executable shell or secret values."""
    value = json.loads(CONFIG.read_text(encoding="utf-8"))
    if value.get("protocol") != 1 or value.get("mode", "controlled") not in ("controlled", "automatic"):
        raise ValueError("Invalid bootstrap configuration")
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9-]{0,62}", value.get("hostname", "")):
        raise ValueError("Invalid declared hostname")
    return value


def prepare() -> None:
    """Explicit automatic mode is only for hosts without external prerequisites."""
    if not CONFIG.exists() or read_record("complete") or read_record("release") or read_record("status"):
        return
    cfg = configuration()
    if cfg.get("mode", "controlled") != "automatic":
        return
    release({
        "protocol": 1, "hostname": cfg["hostname"],
        "vm_id": cfg["vm_id"], "revision": cfg["revision"],
        "attempt": uuid.uuid4().hex, "timeout": cfg.get("timeout", 7200),
    })


def read_record(name: str) -> dict:
    """Read an optional durable record."""
    path = ROOT / f"{name}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def write_record(name: str, value: dict) -> None:
    """Publish a record atomically on the persistent root disk."""
    path = ROOT / f".{name}.tmp"
    with path.open("w", encoding="utf-8") as stream:
        json.dump(value, stream)
        stream.flush()
        os.fsync(stream.fileno())
    path.replace(ROOT / f"{name}.json")


def boot_id() -> str:
    """Return a boot identity that changes on reboot, not on a service restart."""
    return Path("/proc/sys/kernel/random/boot_id").read_text(encoding="utf-8").strip()


def active() -> bool:
    """Include a queued service while it waits for cloud-final to finish."""
    result = subprocess.run(
        [
            "systemctl",
            "show",
            "nixos-bootstrap.service",
            "--property=ActiveState",
            "--value",
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    return result.stdout.strip() in (
        "active",
        "activating",
        "reloading",
        "deactivating",
    )


def snapshot() -> dict:
    """Expose only non-secret provisioning and boot identity."""
    return {
        "protocol": 1,
        "hostname": socket.gethostname().split(".")[0],
        "boot_id": boot_id(),
        "system": os.path.realpath("/run/current-system"),
        "active": active(),
        "status": read_record("status"),
        "release": read_record("release"),
        "complete": read_record("complete"),
    }


def validate_release(value: dict) -> None:
    """Do not turn controller input into a shell or arbitrary flake reference."""
    cfg = configuration()
    if value.get("hostname") != cfg["hostname"]:
        raise ValueError("Release does not match declared hostname")
    if cfg.get("vm_id") is not None and value.get("vm_id") != cfg["vm_id"]:
        raise ValueError("Release belongs to another instance")
    if (
        value.get("protocol") != 1
        or value.get("hostname") != socket.gethostname().split(".")[0]
        or not re.fullmatch(r"[0-9a-f]{40}", value.get("revision", ""))
        or not re.fullmatch(r"[a-zA-Z0-9-]+", value.get("vm_id", ""))
        or not re.fullmatch(r"[0-9a-f]{32}", value.get("attempt", ""))
    ):
        raise ValueError("Invalid bootstrap release")
    if (
        not isinstance(value.get("timeout"), int)
        or isinstance(value["timeout"], bool)
        or not 1 <= value["timeout"] <= 86400
    ):
        raise ValueError("Invalid bootstrap timeout")


def release(value: dict) -> None:
    """Release an idle, incomplete instance only; never replace an active build."""
    validate_release(value)
    if read_record("complete") or active() or read_record("release"):
        raise ValueError("Bootstrap already complete, active or queued")
    if read_record("status").get("stage") == "booting":
        raise ValueError("A pending reboot must be verified before another attempt")
    write_record("release", value)
    subprocess.run(
        ["systemctl", "start", "--no-block", "nixos-bootstrap.service"],
        check=True,
        timeout=10,
    )


def complete(value: dict) -> None:
    """Persist completion only after the intended system has actually booted."""
    status = read_record("status")
    if (
        status.get("stage") != "booting"
        or value.get("vm_id") != status.get("vm_id")
        or value.get("attempt") != status.get("attempt")
        or status.get("boot_id") == boot_id()
        or status.get("system") != os.path.realpath("/run/current-system")
    ):
        raise ValueError("Boot verification failed")
    if status.get("hostname") != socket.gethostname().split(".")[0]:
        raise ValueError("Boot hostname mismatch")
    write_record(
        "complete", {**status, "stage": "complete", "verified_boot_id": boot_id()}
    )


def run_command(command: list[str], deadline: float) -> None:
    """Bound every build operation by the guest's remaining execution budget."""
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("Bootstrap deadline exceeded")
    subprocess.run(command, check=True, timeout=remaining)


def build() -> None:
    """Prepare a generation for next boot and preserve evidence before reboot."""
    cloud = subprocess.run(["cloud-init", "status", "--format=json"], capture_output=True, text=True, check=False)
    if cloud.returncode != 0 or json.loads(cloud.stdout).get("status") != "done":
        raise ValueError("Cloud-init has not completed successfully")
    value = read_record("release")
    validate_release(value)
    if read_record("complete"):
        raise ValueError("Refusing to bootstrap a completed host")
    deadline = time.monotonic() + value["timeout"]
    status = {**value, "stage": "building", "boot_id": boot_id()}
    write_record("status", status)
    (ROOT / "release.json").unlink()
    try:
        target = (
            f'{REPOSITORY}/{value["revision"]}#nixosConfigurations.'
            f'{value["hostname"]}.config.system.build.toplevel'
        )
        result = str(ROOT / "result")
        run_command(
            [
                "nix",
                "build",
                "--no-write-lock-file",
                "--no-update-lock-file",
                "--out-link",
                result,
                target,
            ],
            deadline,
        )
        system = os.path.realpath(result)
        run_command(
            ["nix-env", "--profile", "/nix/var/nix/profiles/system", "--set", system],
            deadline,
        )
        run_command([f"{system}/bin/switch-to-configuration", "boot"], deadline)
        write_record("status", {**status, "stage": "booting", "system": system})
        run_command(["systemctl", "reboot", "--no-block"], deadline)
    except (OSError, ValueError, subprocess.SubprocessError, TimeoutError):
        write_record("status", {**status, "stage": "failed"})
        raise


def main() -> None:
    """Serialize mutations; status remains available during lengthy builds."""
    ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    action = sys.argv[1]
    if action == "status":
        print(json.dumps(snapshot()))
        return
    with (ROOT / "lock").open("w", encoding="utf-8") as lock:
        fcntl.flock(
            lock, fcntl.LOCK_EX if action == "build" else fcntl.LOCK_EX | fcntl.LOCK_NB
        )
        if action == "build":
            build()
        elif action == "prepare":
            prepare()
        elif action == "release":
            release(json.load(sys.stdin))
        elif action == "complete":
            complete(json.load(sys.stdin))
        else:
            raise ValueError("Unknown bootstrap operation")


if __name__ == "__main__":
    main()
