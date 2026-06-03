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
    - [Configure Storage Pool](#configure-storage-pool)
    - [Create Resource Group](#create-resource-group)
    - [Running a test](#running-a-test)
    - [Create Volumes](#create-volumes)

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

- hypervisor-1: combined (controller and satellite)
- hypervisor-2: satellite
- hypervisor-3: satellite
- hypervisor-4: satellite

Each node has the following ZFS datasets:

| ZFS Dataset                                   | Mountpoint         | Description                          |
| --------------------------------------------- | ------------------ | ------------------------------------ |
| zpool/var/lib/linstor                         | /var/lib/linstor   | LINSTOR data and controller database |
| zpool/var/lib/linstor.d                       | /var/lib/linstor.d | LINSTOR metadata                     |
| zpool/var/lib/storage-pools/local             | none               | Local ZFS storage pool               |
| zpool/var/lib/storage-pools/linstor-iso       | none               | ISO storage pool                     |
| zpool/var/lib/storage-pools/linstor-instances | none               | Instances storage pool               |

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

### Initialize LINSTOR Cluster

Run these commands on the controller node which in this example is `hypervisor-1`.

**Note:** This example uses a single controller node. For HA controllers there are a lot more steps involved outside of the scope of this guide.

```bash
# Show the current nodes in the cluster
linstor node list

# Add the controller node (hypervisor-1 runs both controller and satellite)
linstor node create hypervisor-1 10.10.200.11 --node-type combined --communication-type plain

# Add satellite-only nodes
linstor node create hypervisor-2 10.10.200.12 --node-type satellite --communication-type plain
linstor node create hypervisor-3 10.10.200.13 --node-type satellite --communication-type plain
linstor node create hypervisor-4 10.10.200.14 --node-type satellite --communication-type plain

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

# Create a ZFS dataset for DRBD state
sudo zfs create -o mountpoint=/var/lib/drbd zpool/var/lib/drbd

# Create a ZFS dataset for storage pools
sudo zfs create -o mountpoint=none zpool/var/lib/storage-pools

# Create a ZFS dataset for LINSTOR ISO storage pool
sudo zfs create -o mountpoint=none zpool/var/lib/storage-pools/linstor-iso

# Create a ZFS dataset for LINSTOR Instances storage pool
sudo zfs create -o mountpoint=none zpool/var/lib/storage-pools/linstor-instances


# Verify the dataset exists
zfs list | egrep 'linstor|drbd'
```

### Create Storage Pools

**IMPORTANT:** This step creates LINSTOR storage pools that use ZFS as the backend. LINSTOR will then create DRBD resources on top of these storage pools.

```bash
# Create the LINSTOR ISO storage pool backed by ZFS Dataset
linstor storage-pool create zfs hypervisor-1 linstor-iso zpool/var/lib/storage-pools/linstor-iso
linstor storage-pool create zfs hypervisor-2 linstor-iso zpool/var/lib/storage-pools/linstor-iso
linstor storage-pool create zfs hypervisor-3 linstor-iso zpool/var/lib/storage-pools/linstor-iso
linstor storage-pool create zfs hypervisor-4 linstor-iso zpool/var/lib/storage-pools/linstor-iso

# Create the LINSTOR Instances storage pool backed by ZFS Dataset
linstor storage-pool create zfs hypervisor-1 linstor-instances zpool/var/lib/storage-pools/linstor-instances
linstor storage-pool create zfs hypervisor-2 linstor-instances zpool/var/lib/storage-pools/linstor-instances
linstor storage-pool create zfs hypervisor-3 linstor-instances zpool/var/lib/storage-pools/linstor-instances
linstor storage-pool create zfs hypervisor-4 linstor-instances zpool/var/lib/storage-pools/linstor-instances

# Verify storage pools are created and available
linstor storage-pool list
```

### Configure Storage Pool

```bash
# Set StorDriver/ZfscreateOptions on all nodes (ISO Storage Pool)
linstor storage-pool set-property hypervisor-1 linstor-iso StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"
linstor storage-pool set-property hypervisor-2 linstor-iso StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"
linstor storage-pool set-property hypervisor-3 linstor-iso StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"
linstor storage-pool set-property hypervisor-4 linstor-iso StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"

# Set StorDriver/ZfscreateOptions on all nodes (Instances Storage Pool)
linstor storage-pool set-property hypervisor-1 linstor-instances StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"
linstor storage-pool set-property hypervisor-2 linstor-instances StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"
linstor storage-pool set-property hypervisor-3 linstor-instances StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"
linstor storage-pool set-property hypervisor-4 linstor-instances StorDriver/ZfscreateOptions "-o compression=off -o volblocksize=128k"

# Set MaxOversubscriptionRatio on all nodes (ISO Storage Pool)
linstor storage-pool set-property hypervisor-1 linstor-iso MaxOversubscriptionRatio 1
linstor storage-pool set-property hypervisor-2 linstor-iso MaxOversubscriptionRatio 1
linstor storage-pool set-property hypervisor-3 linstor-iso MaxOversubscriptionRatio 1
linstor storage-pool set-property hypervisor-4 linstor-iso MaxOversubscriptionRatio 1

# Set MaxOversubscriptionRatio on all nodes (Instances Storage Pool)
linstor storage-pool set-property hypervisor-1 linstor-instances MaxOversubscriptionRatio 1
linstor storage-pool set-property hypervisor-2 linstor-instances MaxOversubscriptionRatio 1
linstor storage-pool set-property hypervisor-3 linstor-instances MaxOversubscriptionRatio 1
linstor storage-pool set-property hypervisor-4 linstor-instances MaxOversubscriptionRatio 1

# Set StorDriver/WaitTimeoutAfterCreate on all nodes (Controller wide setting)
linstor controller set-property StorDriver/WaitTimeoutAfterCreate 10000
```

### Create Resource Group

Create a resource group for replicated volumes:

```bash
# Create a resource group named 'linstor-iso' with 2-way replication
linstor resource-group create linstor-iso \
  --storage-pool linstor-iso \
  --place-count 2 \
  --diskless-on-remaining true

# Create a resource group named 'linstor-instances' with 2-way replication
linstor resource-group create linstor-instances \
  --storage-pool linstor-instances \
  --place-count 2 \
  --diskless-on-remaining true

# Verify the resource group was created
linstor resource-group list

# Create a volume group for the 'linstor-iso' resource group
linstor volume-group create linstor-iso --gross

# Create a volume group for the 'linstor-instances' resource group
linstor volume-group create linstor-instances --gross

# Verify the volume groups were created (VG 0)
linstor volume-group list linstor-iso
linstor volume-group list linstor-instances
```

### Running a test

Run the following to create and cleanup a test resources.

```bash
# Create a test resource definition (this will create DRBD resources automatically)
linstor resource-group spawn linstor-instances linstor-test-volume 10GiB

# Verify the resource definition was created and DRBD resources were created.
linstor resource-definition list
linstor resource list

# Check DRBD status (should now show resources!)
drbdadm status

# Cleanup the test resource
linstor resource-definition delete linstor-test-volume

# Verify cleanup
linstor resource-definition list
linstor resource list
```

### Create Volumes

Once storage pools and resource groups are set up, you can create volumes that will be automatically replicated.

These can be managed manually with these commands:

```bash
# Create a volume with 3-way replication
linstor resource-group spawn linstor-instances linstor-volume-1 10GiB

# List all resources
linstor resource list

# Check DRBD status to see the replicated resources
drbdadm status
```
