# Generic cloud images

Run `scripts/generate-cloud-image.sh` and select `qemu`, or pass `qemu` for
non-interactive builds. It writes `output/nixos-qemu.img`: compressed qcow2,
x86_64 UEFI with Secure Boot disabled, a 16 GiB expandable ext4 root labelled
`nixos`, and a FAT EFI partition labelled `ESP`. VMware is deferred.

## Guest-owned provisioning (ADR 0041)

`nixos/hosts/base-qemu` imports the generic guest hardware module and the separate
`services.nixos-bootstrap` dispatcher. Cloud-init supplies only public keys,
hostname and non-secret configuration:

```yaml
#cloud-config
hostname: example-host
ssh_authorized_keys:
  - ssh-ed25519 REPLACE_WITH_OPERATOR_PUBLIC_KEY
write_files:
  - path: /etc/nixos-bootstrap/bootstrap.yaml
    owner: root:root
    permissions: "0600"
    content: |
      schema_version: 1
      hostname: example-host
      flake:
        url: github:MAHDTech/nix-config
        ref: trunk
      prerequisites:
        files:
          - /etc/opnix-token
```

Use `files: []` for hosts without prerequisites. A separate task delivers any
credentials; never put tokens in cloud-init, the image or Nix expressions.
The YAML and credential files must be regular runtime files. Both configuration
and state directories are root-owned mode `0700`, on the writable root disk;
there are no `environment.etc` entries for them. The YAML is root-owned `0600`;
OpNix tokens remain `0400` and should be replaced atomically.

The timer checks every 30 seconds. The worker requires successful cloud-init,
valid configuration matching the live hostname, and every prerequisite to be a
readable, non-empty regular file. Missing files mean waiting. Failed cloud-init
and malformed configuration fail visibly in the journal without starting a build.

Each guest independently resolves its configured Git ref once, records the
commit and builds that pinned revision with its flake lock unchanged. The worker
sets the system profile, runs `switch-to-configuration boot`, records the intended
closure and boot ID, then requests reboot. Application services start on the
final OS boot. No controller release, callback or reboot watcher is involved.

The default guest attempt budget is **24 hours**, including ref resolution,
build and boot preparation. Configure it through
`services.nixos-bootstrap.buildTimeoutSeconds` in the bootstrap image. It is
independent of any SSH-preparation deadline. Waiting for prerequisites does not
consume that budget. Builds survive controller disconnection.

## Completion, failures and recovery

Final hosts import `nixos/system/config/services/nixos-bootstrap/completion.nix`
and enable `services.nixos-bootstrap-completion.enable`; they omit the build
dispatcher. The shared QEMU guest module already does this for runners and cache.
The completion service validates persistent machine identity, hostname, a new
boot ID and the exact intended system. It atomically records completion without
contacting a controller. Once complete it ignores later system upgrades, token
rotation and restarts. Retained completion records also protect rollback boots.

State lives in root-only `/var/lib/nixos-bootstrap/`. `status.json` records the
attempt, revision, stages and boot evidence; `complete.json` records verified
completion; `result` is a Nix GC root for the built system, not mutable state.
No record contains credentials. Keep these paths, machine identity and SSH host
keys across adoption and upgrades. Clear them when publishing a new base image.

```bash
cloud-init status --long
journalctl -u nixos-bootstrap.service -b
nixos-bootstrap status
# After diagnosing a failed/interrupted build:
sudo nixos-bootstrap retry
```

Retries are explicit: the next readiness check force-refreshes the configured ref
using `nix flake metadata --refresh`, bypassing cached branch metadata. Initial
attempts also force a refresh; the build then uses the resolved commit with its
lock file unchanged. A lock
prevents overlapping attempts. Failures retain diagnostics and do not automatically
retry. Pending reboot and verification mismatch refuse rebuilds; investigate the
bootloader/system and preserve the evidence. Completed hosts cannot be retried.

OpNix consumers separately check the task's `opnix-pending` marker once a minute,
using the same credential lock as delivery. Successful secret refresh clears the
marker; failure keeps it for retry. This belongs to the OpNix consumer module,
not the generic bootstrap worker.

## Migration and acceptance

This replaces the old JSON configuration and controller release protocol. Do not
change running legacy guests in place. Coordinate a new versioned Prism image
with the ADR 0041 lz-paas configuration and preparation-only hooks; overwriting the
mirror filename does not replace imported images. Existing host upgrade ownership
is unchanged. Publication and fleet deployment are separate operations.

Before publication, test no-prerequisite adoption with no controller, delayed
atomic prerequisite delivery, clone identity isolation, SSH identity retention,
root growth, guest-owned completion, failure/retry behavior and OpNix refresh.

### Local ADR 0041 validation

Two QEMU/KVM clones adopted a minimal final configuration from a local Git flake
fixture. Cloud-init prepared that fixture; the shipping image contains no final
host closure. One clone had no prerequisites and completed unattended. The other
waited through missing and empty file checks, then built and completed after
atomic delivery and SSH disconnection, without any release command.

The clones had distinct machine identities, grew to 24 and 28 GiB, and retained
SSH identity through adoption. Configuration remained a root-owned regular `0600`
file and state directories stayed `0700`. Both wrote completion automatically;
final systems retained the completion unit and omitted the dispatcher. Credential
rotation and a later dispatcher invocation did not rebuild a completed guest.

Twelve worker tests cover validation, locks, pinning, explicit retries, interrupted
attempts and completion across later upgrades. OpNix refresh was checked with a
stub service: failure retains its pending marker and success removes it. Actual
1Password access and Nutanix fleet rollout still require deployment validation.
Statix, Nix formatting, ShellCheck, local-system flake evaluation and image
integrity checks passed.
