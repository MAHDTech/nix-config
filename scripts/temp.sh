#!/usr/bin/env bash

sudo mkdir -p /mnt/nixos

sudo zpool import -f -R /mnt/nixos bpool
sudo zpool import -f -R /mnt/nixos zpool

sudo mount /dev/sda1 /mnt/nixos/boot/efi
sudo mount /dev/sda2 /mnt/nixos/boot/nixos

echo "When ready, run this..."

echo sudo -E nixos-install --verbose --no-root-password --flake .#NUC --impure --root /mnt/nixos
