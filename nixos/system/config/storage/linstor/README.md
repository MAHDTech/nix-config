# LINSTOR for NixOS

## Table of Contents

- [LINSTOR for NixOS](#linstor-for-nixos)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [File Structure](#file-structure)
  - [Example](#example)
  - [Deployment Steps](#deployment-steps)
    - [Deploy to Nodes](#deploy-to-nodes)
    - [Initialize LINSTOR Cluster](#initialize-linstor-cluster)
    - [Create ZFS Datasets (Prerequisites)](#create-zfs-datasets-prerequisites)
    - [Create Storage Pools](#create-storage-pools)
    - [Create Resource Group](#create-resource-group)
    - [Running a test](#running-a-test)
    - [Create Volumes](#create-volumes)
  - [Manual](#manual)

## Overview

An initial implementation of LINSTOR for NixOS. LINSTOR manages DRBD (Distributed Replicated Block Device) resources automatically to provide replicated storage across multiple nodes.

**Key Concepts:**

- **LINSTOR Controller**: Manages the cluster and creates DRBD resources
- **LINSTOR Satellite**: Runs on each storage node, manages local storage
- **DRBD Resources**: Block devices that are replicated between nodes (created automatically by LINSTOR)
- **Storage Pools**: Backend storage (ZFS, LVM, etc.) that LINSTOR uses to create DRBD resources

## Prerequisites

- NixOS systems with flakes enabled.
- At least one controller node and one or more satellite nodes.
- ZFS pools pre-configured on each node if using ZFS for storage.
- Ensure firewall rules allow communication on ports used by LINSTOR (default: 3366 for satellite, 3370-3371 for controller, 7000-7999 for DRBD).

## File Structure

```bash
linstor/
├── packages/             # 📦 DERIVATION: Builds LINSTOR nix packages from deb packages
├── module.nix              # ⚙️ NixOS MODULE: Provides configuration options
├── default.nix             # 🔧 IMPORT: module imports
└── README.md               # 📖 DOCUMENTATION: This file
```

## Example

In this example, we have 4 nodes:

- hypervisor-1: controller and satellite
- hypervisor-2: satellite
- hypervisor-3: satellite
- hypervisor-4: satellite

Each node has the following ZFS datasets:

| ZFS Dataset                        | Mountpoint                    | Description                                 |
| ---------------------------------- | ----------------------------- | ------------------------------------------- |
| zpool/var/lib/linstor              | /var/lib/linstor              | LINSTOR data and controller database        |
| zpool/var/lib/linstor.d            | /var/lib/linstor.d            | LINSTOR metadata                            |
| zpool/var/lib/linstor/storage-pool | /var/lib/linstor/storage-pool | LINSTOR storage pool (ZFS backend for DRBD) |

## Deployment Steps

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
- DRBD service: `systemctl status drbd` (should show "no resources defined!" - this is normal)

### Initialize LINSTOR Cluster

Run these commands on the controller node which in this example is `hypervisor-1`.

**Note:** You only need ONE controller node in the cluster. Other nodes run as satellites only.

```bash
# Show the current nodes in the cluster
linstor node list

# Add the controller node (hypervisor-1 runs both controller and satellite)
linstor node create hypervisor-1 10.10.200.11 --node-type combined

# Add satellite-only nodes
linstor node create hypervisor-2 10.10.200.12 --node-type satellite
linstor node create hypervisor-3 10.10.200.13 --node-type satellite
linstor node create hypervisor-4 10.10.200.14 --node-type satellite

# Disable auto-eviction for satellite nodes (fixed node count).
linstor controller set-property DrbdOptions/AutoEvictAllowEviction false

# Verify all nodes are registered and online
linstor node list

# Verify the nodes have the required packages
linstor node info

# NOTE: To change a node type, run the following command:
# linstor node modify <node-name> --node-type <node-type>
# node-type can be: controller, satellite, combined
# For example, to change the node type of hypervisor-1 to satellite:
# linstor node modify hypervisor-1 --node-type satellite
```

**Troubleshooting:** If nodes show as offline, check network connectivity, firewall rules, and service status on each node.

### Create ZFS Datasets (Prerequisites)

Before creating LINSTOR storage pools, ensure the following ZFS datasets exist on each node:

```bash
# Create a ZFS dataset for LINSTOR data
sudo zfs create -o mountpoint=/var/lib/linstor zpool/var/lib/linstor

# Create a ZFS dataset for LINSTOR metadata
sudo zfs create -o mountpoint=/var/lib/linstor.d zpool/var/lib/linstor.d

# Create a ZFS dataset for LINSTOR storage pool (this will be the backend for DRBD)
sudo zfs create -o mountpoint=/var/lib/linstor/storage-pool zpool/var/lib/linstor/storage-pool

# Verify the dataset exists
zfs list | grep linstor
```

### Create Storage Pools

**IMPORTANT:** This step creates LINSTOR storage pools that use ZFS as the backend. LINSTOR will then create DRBD resources on top of these storage pools.

```bash
# Create LINSTOR storage pools using ZFS as backend on each node
# This tells LINSTOR to use the ZFS dataset as storage for DRBD resources
linstor storage-pool create zfs hypervisor-1 linstor zpool/var/lib/linstor/storage-pool
linstor storage-pool create zfs hypervisor-2 linstor zpool/var/lib/linstor/storage-pool
linstor storage-pool create zfs hypervisor-3 linstor zpool/var/lib/linstor/storage-pool
linstor storage-pool create zfs hypervisor-4 linstor zpool/var/lib/linstor/storage-pool

# Verify storage pools are created and available
linstor storage-pool list
```

### Create Resource Group

Create a resource group for replicated volumes:

```bash
# Create a resource group named 'linstor' with 3-way replication
# This means each volume will be replicated to 3 nodes
linstor resource-group create linstor \
  --storage-pool linstor \
  --place-count 3 \
  --diskless-on-remaining true

# Create a resource group named 'iso' with 2-way replication
# This means each volume will be replicated to 2 nodes
linstor resource-group create iso \
  --storage-pool linstor \
  --place-count 2 \
  --diskless-on-remaining true

# Verify the resource group was created
linstor resource-group list

# Create a volume group for the 'linstor' resource group
linstor volume-group create linstor

# Create a volume group for the 'iso' resource group
linstor volume-group create iso

# Verify the volume group
linstor volume-group list linstor
```

### Running a test

Run the following to create and cleanup a test resources.

```bash
# Create a test resource definition (this will create DRBD resources automatically)
linstor resource-group spawn linstor linstor-test-volume 1GiB

# Verify the resource definition was created and DRBD resources were created.
linstor resource-definition list
linstor resource list

# Check DRBD status (should now show resources!)
drbdadm status

# Cleanup the test resource
linstor resource-definition delete linstor-test-volume

# Verigy cleanup
linstor resource-definition list
linstor resource list
```

### Create Volumes

Once storage pools and resource groups are set up, you can create volumes that will be automatically replicated.

These can be managed by incus, or manually with these commands:

```bash
# Create a volume with 3-way replication
linstor resource-group spawn linstor linstor-volume-1 10GiB

# List all resources
linstor resource list

# Check DRBD status to see the replicated resources
drbdadm status
```

## Manual

Manual steps to create a volume when Incus is being annoying.

```bash
# Create the storage pool on each Node in a "PENDING" state.
incus storage create linstor linstor --target HYPERVISOR-1
incus storage create linstor linstor --target HYPERVISOR-2
incus storage create linstor linstor --target HYPERVISOR-3
incus storage create linstor linstor --target HYPERVISOR-4

# Should show as "PENDING"
incus storage list

# Create the storage pool on each Node in a "CREATED" state.
incus storage create linstor

# Should show as "CREATED"
incus storage list

# Configure the storage pool settings.
incus storage set linstor --property "description" "LINSTOR Storage Pool"
incus storage set linstor "drbd.auto_add_quorum_tiebreaker" "true"
incus storage set linstor "drbd.auto_diskful" "1h"
incus storage set linstor "drbd.on_no_quorum" "suspend-io"
incus storage set linstor "linstor.resource_group.name" "linstor"
incus storage set linstor "linstor.resource_group.place_count" "3"
incus storage set linstor "linstor.resource_group.storage_pool" "linstor"
```
