# GitHub runner VMs

The twenty `github-runner-01` through `github-runner-20` hosts share a common
base configuration. `github-runner-01` through `github-runner-10` register in
the enterprise `tars-cloud` runner group (token reference: `op://fleet/GitHub Runner/credential`),
while `github-runner-11` through `github-runner-20` register in the enterprise
`bingamon-lab` runner group (token reference: `op://Bingamon/GitHub Runner/credential`).
Jobs have Nix, devenv, Cachix, Node 24, Python, C/C++ build tools, Git, and Docker available.

## Build the qcow2 image

Build the shared, workload-free QEMU image:

```bash
./scripts/generate-cloud-image.sh
```

Select `qemu`, or pass `qemu` as the first argument for automation. The output is
`output/nixos-qemu.img` in qcow2 format, with a 16 GiB expandable disk and UEFI
boot. Secure Boot must be disabled. No runner closures or credentials are included.
See [generic cloud images](cloud-images.md) for the configuration and prerequisite contract.

The `github-runner-image` and raw installer outputs remain compatibility entry
points for the same generic bootstrap configuration.

## Bootstrap and secrets

Cloud-init supplies the declared hostname, operator SSH public key and non-secret
`/etc/nixos-bootstrap/bootstrap.yaml`, listing `/etc/opnix-token` as a prerequisite.
A preparation task delivers that token outside cloud-init. The guest independently
pins the configured ref, builds and reboots. The final host keeps only the small
completion service to verify that transition. See ADR 0041 in `bingamon-lab/lz-paas`.

```bash
cloud-init status --long
journalctl -u nixos-bootstrap.service -b
```

The deployment controller and secret-delivery tasks live in `bingamon-lab/lz-paas`.
Publish the selected flake revision before provisioning. Subsequent updates remain
the responsibility of each final host's update configuration.

## Verify each VM

The x86_64 runners support ARM64 userspace through QEMU and binfmt. The shared
final host configuration enables `aarch64-linux` in Nix's extra platforms and
uses a static interpreter for Nix sandboxes and containers. The runner still
advertises GitHub's `X64` label; workflows must explicitly select ARM64 packages
or container platforms and use separate architecture cache keys.

For example, use `nix build .#packages.aarch64-linux.<package>` for a flake that
exports that target, or `docker run --rm --platform linux/arm64 alpine uname -m`.
Emulation supports ARM64 userspace build/test jobs, not an ARM64 kernel or
hardware-specific tests. Compilation can be substantially slower than native.

After deploying the configuration, verify:

```bash
cat /proc/sys/fs/binfmt_misc/aarch64-linux
nix config show extra-platforms
```

The shared `nixos/system/config/services/cloud-init` module enables cloud-init
diagnostics on the bootstrap image and enrolled hosts. It selects `tty1` for
Prism's VGA console and prevents getty from clearing boot output. Other VMs can
import it and enable `services.cloud-init-diagnostics.enable`, optionally setting
`console` and the list of `users` whose home-directory SSH key files are checked.
Networking, users, and datasource settings remain the importing VM's responsibility.

NixOS sshd generates unique host keys on each VM. Cloud-init leaves those keys
alone, and the console report prints their fingerprints using `ssh-keygen`.
This replaces cloud-init's unavailable fingerprint helper and avoids competing
host-key generation. SSH still requires the Bingamon deployment key:

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_bingamon root@<VM-IP>
```

Cloud-init stage output goes to the console and `/var/log/cloud-init-output.log`.
After cloud-final and SSH host-key generation finish, `cloud-init-report.service` prints status, hostname,
addresses, failed cloud-init units, and SSH key-file presence. Key presence does
not guarantee SSH access: account and sshd policy still apply. A failed or hung
cloud-final stage remains visible through its live output; the completion report
cannot run until that stage exits.

Runner bootstrap prints separately to the console, including when it is waiting
for `/etc/opnix-token`, rebuilding, or scheduling a reboot. No token is printed.
To inspect retained output over SSH:

```bash
journalctl -b -u cloud-init -u cloud-config -u cloud-final -u cloud-init-report
journalctl -b -u nixos-bootstrap.service
journalctl -b -t github-runner-build
tail -n 100 /var/log/cloud-init-output.log
```

Test a fresh VM using the new image; updating the Caddy file does not modify
existing guests. Publish these Nix changes to the selected runner flake branch
before bootstrap so the post-reboot host retains the diagnostics configuration.

```bash
hostnamectl --static
systemctl status opnix-secrets.service
systemctl status "github-runner-$(hostname)-enterprise-mahdtech.service"
systemctl list-timers nixos-upgrade.timer
lsblk -f
```

Confirm runners appear online in their respective groups (`bingamon-lab` and `tars-cloud`). Run a trusted workflow
on each hostname label checking Node, Nix, Docker and an actual repository's
devenv shell/tests. Run two jobs in succession to verify ephemeral registration.

Updates run daily at 03:00 Canberra time with up to 30 minutes of jitter and a
two-hour timeout. Every successful update schedules a reboot one minute later,
including userspace-only changes. Failed updates do not reboot. Maintenance can
interrupt jobs. Nix garbage collection runs daily at 02:00 (retaining 3 days),
store deduplication runs at 02:30, and dynamic GC triggers during builds if free
space falls below 15 GiB (clearing up to 35 GiB). Docker prunes unused images
daily, and the journal is capped at 1 GiB. Runner failures retry every 30 seconds;
credential retrieval retries every five minutes.
