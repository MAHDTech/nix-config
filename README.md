# Nix config

> These are my dotfiles, there are many like them but these ones are mine.
>
> - Dotfiles Creed

## Table of Contents

<!-- TOC -->

- [Nix config](#nix-config)
    - [Table of Contents](#table-of-contents)
    - [Overview](#overview)
    - [:warning: Warning](#warning-warning)
        - [Why?](#why)
    - [Layout](#layout)
        - [Folders](#folders)
    - [Setup](#setup)
        - [Bootstrap](#bootstrap)
    - [Usage](#usage)
        - [NixOS](#nixos)
        - [Home Manager](#home-manager)
    - [Development Shells](#development-shells)
    - [Updates](#updates)

<!-- /TOC -->

## Overview

<p align="center">

<img src="docs/images/nix_logo.png" width="300" height="300"/>
<!--
<img src="https://raw.githubusercontent.com/MAHDTech/nix-config/trunk/docs/images/nix_logo.png" width="320" height="320"/>
-->

</p>

<p align="center">

<img src="https://img.shields.io/github/actions/workflow/status/MAHDTech/nix-config/nix_flake_check.yml?label=Check&style=flat-square" alt="Check" />
<img src="https://img.shields.io/github/actions/workflow/status/MAHDTech/nix-config/nix_flake_update.yml?label=Update&style=flat-square" alt="Update" />

</p>

These are my `dotfiles` and system configurations managed as a Nix flake.

The idea behind the configuration layout is split into a few parts;

- _Home_ configuration is managed using Home Manager under [home](home).
- _Host_ configuration contains unique items for individual [hosts](hosts).
- _System_ configuration bundles common system services and programs under [system](system).
- _Shells_ are used to keep the base config lighter and can be found under [shells](shells).

## :warning: Warning

:dragon: Here be dragons :dragon:

_The author is new to using Nix and Nix flakes, and still on their journey to declarative enlightenment, so don't assume they know wtf they are doing or that this repo resembles best practice in any way, shape or form._

### Why?

After managing thousands of servers with CAPS tooling like Ansible and the Salt Project I longed for a declarative, immutable and single-source of truth configuration framework.

Then I found _Nix_ and _NixOS_.

Nix might not be perfect, but it's a hell of a lot better than the brittle, hacked together shell scripts that I have left behind.

NixOS might have a steep learning curve, but it's worth it imo.

![NixOS Learning Curve](docs/images/nixos_curve.png)

## Layout

### Folders

| Name    | Description                               |
| :------ | :---------------------------------------- |
| home    | Home configuration using Home Manager     |
| hosts   | Host specific configuration               |
| system  | System configurations using Nix           |
| shells  | Development shells for specific languages |
| scripts | Scripts not managed with Nix              |

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

**NOTE:** This script (so far) only intended to configure either;

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
    --upgrade-all \
    --flake '.#'
```

Or remotely with;

```bash
nixos-rebuild \
    boot  \
    --use-remote-sudo \
    --upgrade-all \
    --refresh \
    --flake 'github:MAHDTech/nix-config#'
```

### Home Manager

Home Manager changes are switched over with;

```bash
home-manager \
    switch
    --flake .
```

- Or remotely with;

```bash
home-manager \
    switch
    --flake 'github:MAHDTech/nix-config'
```

## Development Shells

_These are a work in progress..._

|    Shell    | Command                                            |
| :---------: | :------------------------------------------------- |
| python 3.11 | nix develop github:MAHDTech/nix-config#python-3_11 |
| python 3.10 | nix develop github:MAHDTech/nix-config#python-3_10 |
| python 3.9  | nix develop github:MAHDTech/nix-config#python-3_9  |
| python 3.8  | nix develop github:MAHDTech/nix-config#python-3_8  |
| python 3.7  | nix develop github:MAHDTech/nix-config#python-3_7  |
| python 2.7  | nix develop github:MAHDTech/nix-config#python-2_7  |

## Updates

Updating the Nix flake lock file `flake.lock` is done via PRs with GitHub Actions.

The manual method is to run the following command within the root of the repository;

```bash
nix flake update
```
