# GitHub runner VMs

The four `github-runner-01` through `github-runner-04` hosts share a QEMU
configuration. Each registers one ephemeral enterprise runner in
`MAHDTech` / `bingamon-lab`. Jobs have Nix, devenv, Cachix, Node 24, Python,
C/C++ build tools, Git, and Docker available.

The enterprise `tars-cloud` group is prepared for JONS. Its configuration
targets that group, but its live registration must remain in `bingamon-lab`
until VM acceptance and the separate JONS cutover.

## Build the qcow2 image

```bash
nix build .#github-runner-image --accept-flake-config --out-link result-github-runner
qemu-img convert -c -O qcow2 result-github-runner/nixos.qcow2 \
  "github-runner-$(date +%Y%m%d).qcow2"
```

This uses nixos-generators' EFI qcow2 format and preloads the runner-01 system
closure. The image boots a neutral cloud-init/bootstrap system with no active
runner, credentials or update timer. It never registers clones as runner 01.
Its 16 GiB virtual disk expands to the disk provisioned by Nutanix; the
deployment specification is UEFI, 8 vCPUs, 16 GiB RAM and 250 GiB disk, in
`vm-workloads` on the IPAM-backed `Nutanix Virtual Machines` subnet with
`backup-none`. Secure Boot must be disabled.

Upload the dated qcow2 to the Caddy images mirror. The deployment configuration
and credential-delivery task live in the `bingamon-lab/lz-paas` repository's
`docs/runbooks/github-runners.md`. For future images update the image name and
URL there together. Review the OpenTofu replacement plan before updating VMs.

The legacy `installer-github-runner-0N` outputs remain raw bootstrap images.
Use `github-runner-image` for this qcow2 deployment path.

## Bootstrap and secrets

Cloud-init must set an exact hostname from `github-runner-01` through
`github-runner-04`, provide the operator's SSH public key, and write
`/etc/github-runner-bootstrap` with a published `RUNNER_FLAKE` reference.
It must not run a competing `nixos-rebuild switch` command.

The deployment task streams the shared 1Password service-account token from
`OPNIX_GITHUB_RUNNERS` into `/etc/opnix-token` over verified SSH. That file is
root-owned, mode `0400`. OpNix subsequently reads the GitHub PAT from
`op://Bingamon/GitHub Runner/credential`. Neither token belongs in cloud-init,
the image, Git, or OpenTofu state.

`github-runner-bootstrap.service` waits for cloud-init, validates the runtime hostname
and token file, builds that flake host's boot generation, then reboots. Failures
retry every five minutes. Inspect it with:

```bash
cloud-init status --long
journalctl -u github-runner-bootstrap -b
```

Publish the approved runner configuration on the `github-runners` branch before
provisioning. Both bootstrap and daily updates read the same `RUNNER_FLAKE`
setting. This lets the VMs update independently of JONS, which follows the
default branch. Publishing the JONS change there can trigger its automatic
cutover; defer that until acceptance.

## Verify each VM

The shared `nixos/system/config/services/cloud-init` module enables cloud-init
diagnostics on the bootstrap image and all four hosts. It selects `tty1` for
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
After cloud-final finishes, `cloud-init-report.service` prints status, hostname,
addresses, failed cloud-init units, and SSH key-file presence. Key presence does
not guarantee SSH access: account and sshd policy still apply. A failed or hung
cloud-final stage remains visible through its live output; the completion report
cannot run until that stage exits.

Runner bootstrap prints separately to the console, including when it is waiting
for `/etc/opnix-token`, rebuilding, or scheduling a reboot. No token is printed.
To inspect retained output over SSH:

```bash
journalctl -b -u cloud-init -u cloud-config -u cloud-final -u cloud-init-report
journalctl -b -u github-runner-bootstrap
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

Confirm all four runners appear online in `bingamon-lab`. Run a trusted workflow
on each hostname label checking Node, Nix, Docker and an actual repository's
devenv shell/tests. Run two jobs in succession to verify ephemeral registration.

Updates run daily at 03:00 Canberra time with up to 30 minutes of jitter and a
two-hour timeout. Every successful update schedules a reboot one minute later,
including userspace-only changes. Failed updates do not reboot. Maintenance can
interrupt jobs. Nix garbage collection retains 14 days, Docker prunes unused
images daily, and the journal is capped at 1 GiB. Runner failures retry every
30 seconds; credential retrieval retries every five minutes.
