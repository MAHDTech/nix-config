# Syncthing Fleet Migration Procedure

This procedure covers migrating JONS from `nix-config` to `fleet`.
Run the provisioning commands from the `fleet` development environment.

## Jons (to Ranger-2)

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
# On the existing Fleet peers
sudo nixos-rebuild switch --flake /home/mahdtech/Sync/Projects/GitHub/tars-cloud/fleet#<hostname>
```

### Checkpoint: Final Synchronization

- [ ] Monitor the Syncthing Web UI on Ranger-2.
- [ ] Verify that all folders display an "Up to Date" status.
- [ ] The migration from `nix-config` to `fleet` is now 100% complete.
