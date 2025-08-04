# LINSTOR for NixOS

## Table of Contents

- [LINSTOR for NixOS](#linstor-for-nixos)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [File Structure](#file-structure)
  - [Deployment Steps](#deployment-steps)
    - [Update Package Hash](#update-package-hash)
    - [Deploy to Nodes](#deploy-to-nodes)
    - [Initialize LINSTOR Cluster](#initialize-linstor-cluster)
    - [Create Storage Pools](#create-storage-pools)

## Overview

An initial implementation of LINSTOR for NixOS.

## Prerequisites

- NixOS systems with flakes enabled.
- At least one controller node and one or more satellite nodes.
- ZFS pools pre-configured on each node if using ZFS for storage (e.g., create a ZFS dataset at `zpool/var/lib/linstor/storage-pools/incus` on each node beforehand).
- Ensure firewall rules allow communication on ports used by LINSTOR (default: 3366 for controller, 3376-3377 for API, etc.).

## File Structure

```bash
linstor/
├── package.nix             # 📦 DERIVATION: Builds LINSTOR from source
├── module.nix              # ⚙️ NixOS MODULE: Provides configuration options
├── default.nix             # 🔧 IMPORT: Clean module import
└── README.md               # 📖 DOCUMENTATION: This file
```

## Deployment Steps

### Update Package Hash

The `package.nix` file uses a placeholder hash (`lib.fakeHash`) for the LINSTOR source.

You need to replace it with the actual SHA256 hash. Attempting a build will fail but reveal the expected hash.

```bash
# Attempt to build the package (this will fail and show the expected hash)
nix build -f ./package.nix

# The error message will include something like:
# got:    sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
# expected: sha256-<correct-hash-here>

# Update the hash in package.nix (adjust the path if your structure differs)
sed -i 's/lib.fakeHash/"sha256-<correct-hash-here>"/' ./package.nix
```

### Deploy to Nodes

Deploy the NixOS configuration to all nodes using flakes.

```bash
# Deploy to controller node (hypervisor-1)
nixos-rebuild switch --flake .#hypervisor-1

# Deploy to satellite nodes
nixos-rebuild switch --flake .#hypervisor-2
nixos-rebuild switch --flake .#hypervisor-3
nixos-rebuild switch --flake .#hypervisor-4
```

After deployment, verify that the LINSTOR services are running:

- On the controller: `systemctl status linstor-controller`
- On satellites: `systemctl status linstor-satellite`

### Initialize LINSTOR Cluster

Run these commands on the controller node which in this example is `hypervisor-1`.

This registers the nodes in the cluster. Specify `--controller` for the controller node and `--satellite` for others.

```bash
# Add the controller node
linstor node create hypervisor-1 10.10.200.1 --controller

# Add satellite nodes
linstor node create hypervisor-2 10.10.200.2 --satellite
linstor node create hypervisor-3 10.10.200.3 --satellite
linstor node create hypervisor-4 10.10.200.4 --satellite

# Verify all nodes are registered and online
linstor node list
```

**Troubleshooting:** If nodes show as offline, check network connectivity, firewall rules, and service status on each node.

### Create Storage Pools

Define storage pools on each node. This example uses ZFS; ensure the underlying ZFS pools/datasets exist on the nodes (e.g., via `zpool create` or `zfs create` beforehand).

```bash
# Create ZFS storage pools on each node
linstor storage-pool create zfs hypervisor-1 incus zpool/var/lib/linstor/storage-pools/incus
linstor storage-pool create zfs hypervisor-2 incus zpool/var/lib/linstor/storage-pools/incus
linstor storage-pool create zfs hypervisor-3 incus zpool/var/lib/linstor/storage-pools/incus
linstor storage-pool create zfs hypervisor-4 incus zpool/var/lib/linstor/storage-pools/incus

# Verify storage pools are created and available
linstor storage-pool list
```

**Next Steps:** Once pools are set up, you can create resource groups, resources, and volumes. Refer to the official LINSTOR documentation for advanced configuration.
