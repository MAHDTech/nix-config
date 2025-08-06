# LINSTOR for NixOS

## Table of Contents

- [LINSTOR for NixOS](#linstor-for-nixos)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [File Structure](#file-structure)
  - [Deployment Steps](#deployment-steps)
    - [Deploy to Nodes](#deploy-to-nodes)
    - [Initialize LINSTOR Cluster](#initialize-linstor-cluster)
    - [Create ZFS Datasets (Prerequisites)](#create-zfs-datasets-prerequisites)
    - [Create Storage Pools](#create-storage-pools)
    - [Create Resource Group](#create-resource-group)
    - [Running a test](#running-a-test)
    - [Create Volumes](#create-volumes)

## Overview

An initial implementation of LINSTOR for NixOS.

## Prerequisites

- NixOS systems with flakes enabled.
- At least one controller node and one or more satellite nodes.
- ZFS pools pre-configured on each node if using ZFS for storage (e.g., create a ZFS dataset at `zpool/var/lib/linstor/storage-pool` on each node beforehand).
- Ensure firewall rules allow communication on ports used by LINSTOR (default: 3366 for controller, 3376-3377 for API, etc.).

## File Structure

```bash
linstor/
├── packages/             # 📦 DERIVATION: Builds LINSTOR nix packages from deb packages
├── module.nix              # ⚙️ NixOS MODULE: Provides configuration options
├── default.nix             # 🔧 IMPORT: module imports
└── README.md               # 📖 DOCUMENTATION: This file
```

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

# Verify all nodes are registered and online
linstor node list

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

# Create a ZFS dataset for LINSTOR storage pool
sudo zfs create -o mountpoint=/var/lib/linstor/storage-pool zpool/var/lib/linstor/storage-pool

# Verify the dataset exists
zfs list | grep linstor
```

### Create Storage Pools

Define storage pools on each node using the ZFS datasets created above.

```bash
# Create a LINSTOR storage pool backed by the ZFS dataset on each node.
linstor storage-pool create zfs hypervisor-1 linstor zpool/var/lib/linstor/storage-pool
linstor storage-pool create zfs hypervisor-2 linstor zpool/var/lib/linstor/storage-pool
linstor storage-pool create zfs hypervisor-3 linstor zpool/var/lib/linstor/storage-pool
linstor storage-pool create zfs hypervisor-4 linstor zpool/var/lib/linstor/storage-pool

# Verify storage pools are created and available
linstor storage-pool list
```

### Create Resource Group

Create a resource group for Incus containers with replication:

```bash
# Create a resource group named 'incus' with 3-way replication
linstor resource-group create linstor \
  --storage-pool linstor \
  --place-count 3

# Verify the resource group was created
linstor resource-group list

# Create a volume group for the resource group
linstor volume-group create linstor

# Verify the volume group
linstor volume-group list linstor
```

### Running a test

Run the following to create and cleanup a test resources.

```bash
# Create a test resource
linstor resource-group spawn linstor linstor-test 1GiB

# Verify the resource was created
linstor resource list

# Cleanup the test resource
linstor resource-definition delete linstor-test
```

### Create Volumes

Once storage pools and resource groups are set up, you can configure the incus module to dynamically create volumes as needed.
