# nix-config

> These are my dotfiles, there are many like them but these ones are mine.
>
> - Dotfiles Creed

## Table of Contents

<!-- TOC -->

- [nix-config](#nix-config)
    - [Table of Contents](#table-of-contents)
    - [Layout](#layout)
        - [Hosts](#hosts)
        - [Folders](#folders)
    - [Setup](#setup)
        - [Bootstrap](#bootstrap)
    - [Usage](#usage)
        - [NixOS](#nixos)
        - [Home Manager](#home-manager)
    - [Development Shells](#development-shells)
    - [Updates](#updates)

<!-- /TOC -->

## Layout

### Hosts

| Name    | Operating System                 |
| :------ | :------------------------------- |
| penguin | Debian Linux (ChromeOS Crostini) |
| nuc     | NixOS                            |

### Folders

| Name         | Description                               |
| :----------- | :---------------------------------------- |
| dev-shells   | Development shells for specific languages |
| scripts      | Generic scripts for different purposes    |
| hosts        | System configuration for NixOS            |
| home-manager | Home configuration using Home Manager     |

## Setup

### Bootstrap

- Clone this repo

```bash
export NIX_CONFIG_REPO="https://github.com/MAHDTech/nix-config.git"

git clone ${NIX_CONFIG_REPO}
cd nix-config
```

- Review and run the script.

---
**NOTE:** This script is only intended to configure either;

- A ZFS on root install on NixOS (NixOS & Home Manager)
- A ChromeOS Debian Linux container (Home Manager only)

---

```bash
# Review and modify the defined variables as required.
vim ./scripts/bootstrap.sh

# Run the script
./scripts/bootstrap.sh
```

## Usage

### NixOS

NixOS changes are applied on each boot.

```bash
nixos-rebuild \
    boot  \
    --use-remote-sudo \
    --upgrade \
    --flake '.#'
```

### Home Manager

Home Manager changes are switched over live.

```bash
home-manager \
    switch
    --flake .
```

## Development Shells

_This is a work in progress..._

|    Shell    | Command                                            |
| :---------: | :------------------------------------------------- |
| python 3.11 | nix develop github:MAHDTech/nix-config#python-3_11 |
| python 3.10 | nix develop github:MAHDTech/nix-config#python-3_10 |
| python 3.9  | nix develop github:MAHDTech/nix-config#python-3_9  |
| python 3.8  | nix develop github:MAHDTech/nix-config#python-3_8  |
| python 3.7  | nix develop github:MAHDTech/nix-config#python-3_7  |
| python 2.7  | nix develop github:MAHDTech/nix-config#python-2_7  |

## Updates

Updating of the Nix flake lock file `flake.lock` is now done via PRs with GitHub Actions.

The manual method is;

```bash
nix flake update
```
