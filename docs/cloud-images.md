# Generic cloud images

Run `scripts/generate-cloud-image.sh` and select `qemu`, or pass `qemu` as an
argument. It builds `.#qemu-image` and writes `output/nixos-qemu.img` (qcow2).
VMware and public-cloud outputs are deferred. The image is x86_64, UEFI without
Secure Boot, GPT, ext4 root labelled `nixos` and FAT EFI partition labelled `ESP`.
The initial 16 GiB virtual disk grows to the provisioned size on boot.

`nixos/hosts/base-qemu` imports the reusable guest hardware/disk module and the
separate `services.nixos-bootstrap` module. Final QEMU hosts import the guest
module but not the bootstrap module. No application closures, credentials, SSH
keys, registration or fleet upgrade timers belong in this base image.

Cloud-init supplies hostname, operator public keys and this non-secret file:

```yaml
#cloud-config
hostname: example-host
ssh_authorized_keys:
  - ssh-ed25519 REPLACE_WITH_OPERATOR_PUBLIC_KEY
write_files:
  - path: /etc/nixos-bootstrap.json
    owner: root:root
    permissions: "0600"
    content: |
      {"protocol": 1, "hostname": "example-host", "mode": "controlled"}
```

Cloud-init never waits for prerequisites. The controller verifies instance
identity, delivers secrets through a separate mechanism, and invokes:

```bash
python3 /var/lib/nixos-bootstrap/worker.py release < release.json
```

The root-owned release contains `protocol: 1`, `hostname`, provider `vm_id`, a
40-character `revision` in `MAHDTech/nix-config`, a unique 32-character hexadecimal
`attempt`, and `timeout` in seconds (1–86400). No secrets belong in these records.
An optional `vm_id` in configuration restricts release to that expected instance.
The current controller verifies identity independently through Prism and SSH.

For hosts with no external prerequisites, explicit `mode: automatic` additionally
requires `revision` and `vm_id` in configuration. It makes one initial attempt;
a failed attempt requires diagnosis and an explicit controller release to retry.

The worker builds with the pinned lock unchanged, sets the system profile,
activates with `switch-to-configuration boot`, records the intended system and
boot identity, then reboots. It does not activate application services live.
`status`, `release` and `complete` CLI actions retain the protocol-1 controller
interface. Completion requires a different boot ID and the exact intended system.

The final host omits the bootstrap module. Its service and timers disappear from
the active configuration, while Python, the durable protocol client and records
remain available for verification. Preserve injected operator access, SSH host
keys, disk labels and `/etc/opnix-token` where used. Old generations still exist;
completion and pending-boot records prevent treating rollback as new provisioning.

Before publication, boot two fresh clones, verify unique identities, DHCP,
guest-agent discovery, key-only SSH, cloud-init completion and root growth.
Verify a minimal final host adoption and reboot with unchanged SSH identity.
Nutanix acceptance and publishing to the image mirror are deployment operations.

## Validation

Local QEMU/KVM acceptance on 2026-09-21 verified UEFI boot, NoCloud hostname,
key injection, `write_files`, `runcmd`, DHCP, guest-agent address reporting and
root growth on independent 20 GiB and 24 GiB clones. Machine IDs and SSH host
keys differed between clones. A fresh final-build clone also grew to 28 GiB.

A minimal final configuration was built locally and supplied through a local
flake fixture for the adoption test; the worker's repository constant was
redirected only in that test VM. The actual Nix build/profile/boot/reboot flow
preserved identity, booted the exact intended system, removed the bootstrap
service and timer, and allowed the controller to record verified completion.
This tests adoption mechanics without claiming a live GitHub runner deployment.

The compressed artifact passed `qemu-img check`; flake evaluation, ShellCheck,
eight local worker tests and 17 related controller compatibility tests passed.
Nutanix/Prism import and live fleet provisioning remain deployment acceptance
checks, not operations performed by the local image builder.
