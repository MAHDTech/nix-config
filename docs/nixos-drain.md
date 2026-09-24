# Host draining

`nixos-drain` runs a named, root-owned application script before planned disruption.
It is enabled on `github-runner-01` through `github-runner-20`, `s3` and `nix-cache`.
Other hosts and installer images do not import the module.

```bash
nixos-drain status
sudo nixos-drain drain --profile upgrade
sudo nixos-drain drain --profile destroy
sudo nixos-drain drain --profile maintenance
sudo nixos-drain cancel
```

`drain` waits and exits zero only after the script succeeds. The systemd worker
continues if SSH disconnects or the waiting command is interrupted. `status` shows
the profile, state, elapsed time, timeout, latest script output and journal command.
Scripts should print short progress lines and flush buffered output.

Only one drain can own a host. Repeating its profile joins the current attempt or
returns its successful result. Another profile is rejected until cancellation.
Failed and timed-out attempts require explicit cancellation before retrying unless
the profile enables `cancelOnFailure`. With that option, failure or worker
termination automatically starts cancellation; the drain caller still fails.
Cleanup failures remain visible and require an explicit `cancel` retry.

`cancel` stops the drain script and runs that profile's cancellation script. It
does not stop the application service. Successful cleanup releases the host for a
new drain; failed cleanup remains visible and can be retried with `cancel`.
Cancellation scripts must tolerate partial drains and repeated execution.

## Configuration

Import `nixos/system/config/services/nixos-drain` on the intended host:

```nix
services.nixos-drain = {
  enable = true;
  timeoutSeconds = 3600;
  profiles = {
    upgrade = {
      cancelOnFailure = true;
      script = ''
        ${myApplication}/bin/drain
      '';
      cancelScript = ''
        ${myApplication}/bin/resume
      '';
    };
    destroy = {
      timeoutSeconds = 7200;
      script = ''
        ${myApplication}/bin/drain
      '';
      cancelScript = ''
        ${myApplication}/bin/resume
      '';
    };
  };
};
```

`upgrade`, `destroy` and `maintenance` exist by default. Additional profile names
are allowed. Every profile inherits the global timeout unless overridden; the
same limit applies separately to cancellation cleanup. Commands run with
`NIXOS_DRAIN_PROFILE` set. Use Nix store paths for application tools and keep
secrets out of these scripts and their output.

The module generates `/etc/nixos-drain/config.json`, referencing executable scripts
in the Nix store. Do not edit it manually. With an empty script, the profile sends
a `wall` message and immediately succeeds. Status calls this `notification-only`;
it does not establish application safety. S3 and nix-cache use these defaults.

Mutable state is root-owned under `/run/nixos-drain` and readable for status.
Configuration is captured when an attempt starts, so cancellation uses that
attempt's cleanup script even if the host configuration changes. State resets on
reboot. A successful drain applies only to the current boot: drain again if the
host unexpectedly reboots before deletion.

## GitHub runners

The runner-specific module supplies all three profiles with the same handler.
An `ExecCondition` checks a maintenance marker before each new registration. The
gate and drain request share a lock. Starts admitted before the marker may finish
their registration and one job; subsequent registrations are skipped.

The handler waits for every runner service to become inactive, including startup,
job execution and service cleanup. It never sends a stop signal to a live runner.
Cancellation removes the marker and starts inactive services without restarting
active ones. Token rotation is picked up at the next ephemeral registration,
rather than restarting a runner mid-job.

An idle, already registered runner is allowed one final job. If no job arrives,
the drain can time out. The runner `upgrade` profile enables `cancelOnFailure`:
timeout or failure removes the maintenance marker and starts inactive services,
without interrupting a running job. The upgrade fails without rebooting and can
retry on its next schedule. Destroy and maintenance profiles keep the marker
until an explicit `cancel`. Missing or failed services are reported as errors
rather than assumed safe.

Previously, an upgrade timeout left the marker in place. A runner could remain
connected for hours, finish its next job successfully, then disappear because
its next registration was blocked. Automatic upgrade cancellation prevents this
delayed loss of capacity. An attempt created before this change still uses its
captured settings and needs a one-time `nixos-drain cancel`.

## Upgrades and Terraform

Runner upgrades stage a boot generation, drain the `upgrade` profile, then request
a reboot only on success. If the staged generation is already booted, they skip
the drain and reboot. A failed or cancelled drain prevents that reboot. Host
upgrade times are [staggered within each group](github-runners.md).
S3 and nix-cache run their notification-only profile before their existing
`switch` upgrade and cancel it after success; neither gains automatic reboots.

For a Terraform/OpenTofu destroy hook, run:

```bash
sudo nixos-drain drain --profile destroy
```

Leave failure handling enabled so a nonzero result blocks destruction. The command
does not shut down or delete the host. A successful application handler must leave
the application drained until cancellation or reboot. Once a caller receives
success and starts deletion or reboot, `cancel` cannot recall that action.

This is a cooperative lab mechanism. Forced shutdowns, direct service restarts,
manual VM deletion and destroy paths that skip provisioners bypass it. There is
no fleet-wide capacity policy or job migration.

## Verification

```bash
python3 -m unittest discover -s tests -p test_nixos_drain.py -v
nix build .#checks.x86_64-linux.nixos-drain --no-link
```

The VM test uses simulated ephemeral jobs and real systemd services. It checks
registration gating, completion, cancellation, timeout, worker termination,
notification-only profiles and reboot reset without GitHub credentials.
