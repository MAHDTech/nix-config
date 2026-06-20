# Syncthing Fleet Migration Procedure

This document outlines the sequential, rolling migration of hosts from the
stateful `nix-config` architecture to the ephemeral `fleet` architecture. This
strategy ensures zero data loss by generating new Syncthing IDs for each newly
provisioned host and seeding data back from the remaining legacy nodes.

## Pre-requisites

- Ensure you are inside the `fleet` development environment when running `nixos-anywhere`.
- Run: `nix develop --no-pure-eval` or `devenv shell` from the fleet repository root.

---

## 1. Zenbook

### Phase 1: Provisioning

Deploy the ephemeral `fleet` configuration to Zenbook. This will wipe the disk and format it with `bcachefs`.

```bash
# From the fleet repository root
nixos-anywhere --flake .#zenbook root@<zenbook-ip-address>
```

### Checkpoint: ID Extraction

- [ ] Wait for Zenbook to boot successfully.
- [ ] Access the Syncthing Web UI on Zenbook (`http://<zenbook-ip>:8384` or via localhost if tunneled).
- [ ] Extract the newly generated Syncthing Device ID.

### Phase 2: Peer Re-alignment

Update the legacy hosts to recognize the new Zenbook ID.

- Edit `/boot/nixos/nix-config/nixos/hosts/{orion,jons,bootycall}/home-manager/syncthing.nix` (or equivalent).
- Replace the old Zenbook ID with the newly generated ID.
- Apply the changes on the legacy hosts:

```bash
# On Orion, Jons, and Bootycall
sudo nixos-rebuild switch --flake /boot/nixos/nix-config#<hostname>
```

### Checkpoint: Synchronization

- [ ] Monitor the Syncthing Web UI on Zenbook.
- [ ] Verify that all folders display an "Up to Date" status.
- [ ] Ensure the file counts match the expected legacy state. Do not proceed until Zenbook has fully synced from the legacy cluster.

---

## 2. Orion

### Phase 1: Provisioning

Deploy the ephemeral `fleet` configuration to Orion.

```bash
# From the fleet repository root
nixos-anywhere --flake .#orion root@<orion-ip-address>
```

### Checkpoint: ID Extraction

- [ ] Wait for Orion to boot successfully.
- [ ] Access the Syncthing Web UI on Orion.
- [ ] Extract the newly generated Syncthing Device ID.

### Phase 2: Peer Re-alignment

Update both the legacy and the already-migrated fleet hosts.

- **Legacy**: Edit `/boot/nixos/nix-config` to replace the Orion ID for Jons and Bootycall.
- **Fleet**: Update `fleet` configuration (e.g. `fleet/home/services/syncthing/default.nix`) to replace the old Orion ID with the new one, and apply to Zenbook.

```bash
# On Jons and Bootycall (Legacy)
sudo nixos-rebuild switch --flake /boot/nixos/nix-config#<hostname>

# On Zenbook (Fleet)
sudo nixos-rebuild switch --flake /home/mahdtech/Sync/Projects/GitHub/tars-cloud/fleet#zenbook
```

### Checkpoint: Synchronization

- [ ] Monitor the Syncthing Web UI on Orion.
- [ ] Verify that all folders display an "Up to Date" status before proceeding.

---

## 3. Bootycall

### Phase 1: Provisioning

Deploy the ephemeral `fleet` configuration to Bootycall.

```bash
# From the fleet repository root
nixos-anywhere --flake .#bootycall root@<bootycall-ip-address>
```

### Checkpoint: ID Extraction

- [ ] Wait for Bootycall to boot successfully.
- [ ] Access the Syncthing Web UI on Bootycall.
- [ ] Extract the newly generated Syncthing Device ID.

### Phase 2: Peer Re-alignment

Update the legacy and fleet hosts.

- **Legacy**: Edit `/boot/nixos/nix-config` to replace the Bootycall ID for Jons.
- **Fleet**: Update `fleet` configuration to replace the old Bootycall ID with the new one, and apply to Zenbook and Orion.

```bash
# On Jons (Legacy)
sudo nixos-rebuild switch --flake /boot/nixos/nix-config#jons

# On Zenbook and Orion (Fleet)
sudo nixos-rebuild switch --flake /home/mahdtech/Sync/Projects/GitHub/tars-cloud/fleet#<hostname>
```

### Checkpoint: Synchronization

- [ ] Monitor the Syncthing Web UI on Bootycall.
- [ ] Verify that all folders display an "Up to Date" status before proceeding.

---

## 4. Jons (to Ranger-2)

### Phase 1: Provisioning

Deploy the ephemeral `fleet` configuration to Jons (now Ranger-2).

```bash
# From the fleet repository root
nixos-anywhere --flake .#ranger-2 root@<jons-ip-address>
```

### Checkpoint: ID Extraction

- [ ] Wait for Ranger-2 to boot successfully.
- [ ] Access the Syncthing Web UI on Ranger-2.
- [ ] Extract the newly generated Syncthing Device ID.

### Phase 2: Peer Re-alignment

Since Jons is the last node, all other nodes are now on `fleet`. Update the `fleet` configuration for all previously migrated hosts.

- Update `fleet` configuration to replace the old Jons ID with the new Ranger-2 ID.

```bash
# On Zenbook, Orion, and Bootycall (Fleet)
sudo nixos-rebuild switch --flake /home/mahdtech/Sync/Projects/GitHub/tars-cloud/fleet#<hostname>
```

### Checkpoint: Final Synchronization

- [ ] Monitor the Syncthing Web UI on Ranger-2.
- [ ] Verify that all folders display an "Up to Date" status.
- [ ] The migration from `nix-config` to `fleet` is now 100% complete.
