#!/usr/bin/env python3
"""Guest-owned, provisioning-only bootstrap (ADR 0041). No secret transport."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import socket
import stat
import subprocess
import sys
import time
import uuid
from urllib.parse import quote, urlsplit

import yaml

ROOT = Path("/var/lib/nixos-bootstrap")
CONFIG = Path("/etc/nixos-bootstrap/bootstrap.yaml")
MACHINE_ID = Path("/etc/machine-id")
BOOT_ID = Path("/proc/sys/kernel/random/boot_id")
CURRENT_SYSTEM = Path("/run/current-system")


def identity():
    value = MACHINE_ID.read_text().strip()
    if not re.fullmatch(r"[0-9a-f]{32}", value):
        raise ValueError("Missing persistent machine identity")
    return {"machine_id": value, "hostname": socket.gethostname().split(".")[0]}


def read_record(name):
    path = ROOT / f"{name}.json"
    if not path.exists():
        return {}
    if path.is_symlink() or not path.is_file():
        raise ValueError("State must be a regular runtime file")
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError("Invalid state record")
    return value


def write_record(name, value):
    path = ROOT / f".{name}-{uuid.uuid4().hex}.tmp"
    try:
        with path.open("x", encoding="utf-8") as stream:
            os.chmod(path, 0o600)
            json.dump(value, stream)
            stream.flush()
            os.fsync(stream.fileno())
        path.replace(ROOT / f"{name}.json")
        fd = os.open(ROOT, os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        path.unlink(missing_ok=True)


def check_identity(record):
    if any(record.get(k) != v for k, v in identity().items()):
        raise ValueError("Bootstrap record belongs to another machine or hostname")


def configuration():
    if (
        CONFIG.is_symlink()
        or str(CONFIG.resolve()).startswith("/nix/store/")
        or not CONFIG.is_file()
    ):
        raise ValueError("Configuration must be a regular runtime file")
    info = CONFIG.stat()
    if info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
        raise ValueError("Configuration must be root-owned with mode 0600")
    try:
        value = yaml.safe_load(CONFIG.read_text())
    except yaml.YAMLError:
        raise ValueError("Invalid bootstrap YAML") from None
    if (
        not isinstance(value, dict)
        or type(value.get("schema_version")) is not int
        or value["schema_version"] != 1
    ):
        raise ValueError("Expected bootstrap schema_version: 1")
    host = value.get("hostname")
    if not isinstance(host, str) or not re.fullmatch(
        r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?", host
    ):
        raise ValueError("Invalid hostname")
    if host != identity()["hostname"]:
        raise ValueError("Configured hostname does not match live hostname")
    flake = value.get("flake")
    if not isinstance(flake, dict) or any(
        not isinstance(flake.get(k), str) or not flake[k] for k in ("url", "ref")
    ):
        raise ValueError("flake.url and flake.ref must be non-empty strings")
    url, ref = flake["url"], flake["ref"]
    if any(c.isspace() for c in url) or "#" in url or "?" in url:
        raise ValueError("Use a base flake URL without query or fragment")
    if url.startswith(("github:", "gitlab:")):
        if not re.fullmatch(r"(github|gitlab):[\w.-]+/[\w.-]+", url):
            raise ValueError("Invalid hosted Git flake URL")
    elif url.startswith(("git+https://", "git+ssh://", "git+file://")):
        parsed = urlsplit(url[4:])
        if parsed.password or (parsed.scheme == "https" and parsed.username):
            raise ValueError("Credentials must not be embedded in the flake URL")
    else:
        raise ValueError("Use a Git-backed flake URL")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", ref) or ".." in ref:
        raise ValueError("Invalid flake ref")
    prerequisites = value.get("prerequisites", {"files": []})
    files = prerequisites.get("files", []) if isinstance(prerequisites, dict) else None
    if not isinstance(files, list) or any(
        not isinstance(p, str)
        or not p.startswith("/")
        or "\0" in p
        or ".." in Path(p).parts
        for p in files
    ):
        raise ValueError("prerequisites.files must contain absolute paths")
    return {"hostname": host, "flake": flake, "files": files}


def file_ready(path):
    path = Path(path)
    try:
        if path.is_symlink() or "/nix/store" in str(path.resolve()):
            return False
        info = path.stat()
        return (
            stat.S_ISREG(info.st_mode)
            and info.st_size > 0
            and bool(info.st_mode & 0o444)
            and os.access(path, os.R_OK)
        )
    except OSError:
        return False


def command(args, deadline, capture=False):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("Guest build budget exceeded")
    # Kill the whole process group on timeout, including build helper children.
    with subprocess.Popen(
        args,
        stdout=subprocess.PIPE if capture else None,
        text=True,
        start_new_session=True,
    ) as process:
        try:
            output, _ = process.communicate(timeout=remaining)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
        if process.returncode:
            raise RuntimeError(f"Command failed: {args[0]} (exit {process.returncode})")
        return output


def completed():
    record = read_record("complete")
    if record:
        check_identity(record)
        return True
    return False


def dispatch(timeout):
    if completed():
        return
    old = read_record("status")
    if old:
        check_identity(old)
        if old.get("stage") in ("resolving", "building", "activating"):
            # We own the lock, so this is an interrupted, not concurrent, build.
            write_record(
                "status",
                {
                    **old,
                    "stage": "failed",
                    "error": "Interrupted attempt; explicit retry required",
                },
            )
        return
    if (ROOT / "release.json").exists() or Path("/etc/nixos-bootstrap.json").exists():
        raise ValueError(
            "Legacy bootstrap state/configuration requires explicit migration"
        )
    cloud = subprocess.run(
        ["cloud-init", "status", "--format=json"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if cloud.returncode or json.loads(cloud.stdout).get("status") != "done":
        raise ValueError(
            "Cloud-init has not completed successfully; inspect cloud-init status --long"
        )
    if not CONFIG.exists():
        print("Waiting for bootstrap configuration", flush=True)
        return
    cfg = configuration()
    if not all(file_ready(p) for p in cfg["files"]):
        print("Waiting for prerequisite files", flush=True)
        return
    deadline = time.monotonic() + timeout
    record = {
        **identity(),
        "schema_version": 1,
        "attempt": uuid.uuid4().hex,
        "boot_id": BOOT_ID.read_text().strip(),
        "stage": "resolving",
    }
    write_record("status", record)
    try:
        flake = cfg["flake"]
        reference = (
            flake["url"]
            + ("/" if flake["url"].startswith(("github:", "gitlab:")) else "?ref=")
            + quote(flake["ref"], safe="/")
        )
        metadata = json.loads(
            command(
                [
                    "nix",
                    "flake",
                    "metadata",
                    "--refresh",
                    "--accept-flake-config",
                    "--json",
                    "--no-write-lock-file",
                    "--no-update-lock-file",
                    reference,
                ],
                deadline,
                True,
            )
        )
        revision = metadata.get("locked", {}).get("rev")
        if not isinstance(revision, str) or not re.fullmatch(
            r"[0-9a-f]{40,64}", revision
        ):
            raise ValueError("Configured ref did not resolve to a Git commit")
        pinned = flake["url"] + (
            "/" + revision
            if flake["url"].startswith(("github:", "gitlab:"))
            else "?rev=" + revision
        )
        record.update(stage="building", revision=revision, flake=pinned)
        write_record("status", record)
        command(
            [
                "nix",
                "build",
                "--accept-flake-config",
                "--no-write-lock-file",
                "--no-update-lock-file",
                "--out-link",
                str(ROOT / "result"),
                f"{pinned}#nixosConfigurations.{cfg['hostname']}.config.system.build.toplevel",
            ],
            deadline,
        )
        system = str((ROOT / "result").resolve(strict=True))
        if not system.startswith("/nix/store/"):
            raise ValueError("Build did not return a Nix system closure")
        record.update(stage="activating", system=system)
        write_record("status", record)
        command(
            ["nix-env", "--profile", "/nix/var/nix/profiles/system", "--set", system],
            deadline,
        )
        command([f"{system}/bin/switch-to-configuration", "boot"], deadline)
        record["stage"] = "booting"
        write_record("status", record)
        command(["systemctl", "reboot", "--no-block"], deadline)
    except Exception as error:
        # Pending boot must not become permission to start a different build.
        if record["stage"] != "booting":
            record["stage"] = "failed"
        record["error"] = type(error).__name__ + "; inspect the journal"
        write_record("status", record)
        raise


def complete():
    if completed():
        return
    record = read_record("status")
    if not record or record.get("stage") not in ("booting", "verification-failed"):
        return
    check_identity(record)
    if record.get("boot_id") == BOOT_ID.read_text().strip() or record.get(
        "system"
    ) != str(CURRENT_SYSTEM.resolve()):
        write_record(
            "status",
            {
                **record,
                "stage": "verification-failed",
                "error": "Boot identity or running system mismatch",
            },
        )
        raise ValueError("Bootstrap boot verification failed")
    write_record(
        "complete",
        {
            **record,
            "stage": "complete",
            "verified_boot_id": BOOT_ID.read_text().strip(),
        },
    )


def retry():
    if completed():
        raise ValueError(
            "Bootstrap already completed. To update this machine, run: "
            "systemctl start nixos-upgrade.service"
        )
    record = read_record("status")
    if record:
        check_identity(record)
        if record.get("stage") not in ("failed", "resolving", "building", "activating"):
            raise ValueError(
                "Pending boot or verification failure must be investigated, not rebuilt"
            )
        write_record("previous-attempt", record)
        (ROOT / "status.json").unlink()
    print(
        "Retry authorized; the next readiness check will force-refresh the configured ref"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["run", "complete", "retry", "status"])
    parser.add_argument("--timeout", type=int, default=86400)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    os.umask(0o077)
    if ROOT.is_symlink() or "/nix/store" in str(ROOT.resolve()):
        raise ValueError("State directory must be writable runtime storage")
    ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    if args.action == "status":
        print(
            json.dumps(
                {"status": read_record("status"), "complete": read_record("complete")}
            )
        )
        return
    with (ROOT / "lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            if args.action == "retry":
                raise ValueError("An attempt is active; retry refused") from None
            return
        if args.action == "run":
            dispatch(args.timeout)
        elif args.action == "complete":
            complete()
        else:
            retry()


def cli():
    try:
        main()
    except (ValueError, RuntimeError, OSError) as error:
        print(f"nixos-bootstrap: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    cli()
