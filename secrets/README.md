# Readme

## Table of Contents

- [Readme](#readme)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Environment Variables](#environment-variables)
  - [Editing the keystore](#editing-the-keystore)
  - [Obtaining Keys](#obtaining-keys)
    - [Age](#age)
    - [SSH to Age](#ssh-to-age)

## Overview

Notes to remember as I use `sops` so infrequently.

**All commands are run relative to the root of the repository.**

## Environment Variables

- Set the `SOPS_AGE_KEY_FILE` environment variable to the path of the `age` keys file.

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
export SOPS_AGE_PUB_FILE=~/.config/sops/age/keys.pub
```

## Editing the keystore

- Edit the `keystore.yaml` file to add new secrets.

```bash
nix-shell -p sops --run "sops secrets/keystore.yaml"
```

## Editing allowed hosts and user keys

- Add a new host and update the keys.

```bash
# Add your SOPS keys and save.
vim .sops.yaml
```

- Now, re-encrypt the file with the new keys.

```bash
# Edit and save the file.
nix-shell -p sops --run "sops secrets/keystore.yaml"

# Update the keys for all secrets.
nix-shell -p sops --run "sops updatekeys secrets/keystore.yaml"
```

- If you need to update the keys root key

```bash
sudo -E sh -c '\
    SOPS_AGE_KEY_FILE=/root/.config/sops/age/keys.txt \
    nix-shell -p sops --run "sops updatekeys /boot/nixos/nix-config/secrets/keystore.yaml" \
'
```

## Obtaining Keys

### Age

- If you want to generate a new `age` key, run the following command.

**NOTE:** \_This creates a new identity.

You must:

- add its public key (age-keygen -y keys.txt) as a recipient in keystore.yaml
- and, run `sops updatekeys` from a host that can already decrypt
- otherwise this new key can’t read existing secrets.

```bash
nix-shell -p age --run "age-keygen -o ${SOPS_AGE_KEY_FILE}"
```

### SSH to Age

#### Public Keys

- To obtain the `age` _public_ key for a host, run the following command:

```bash
mkdir --parents ~/.config/sops/age

nix-shell -p ssh-to-age

ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub >> ~/.config/sops/age/keys.pub
```

- To obtain the `age` _public_ key for a user, run the following command:

```bash
ssh-to-age -i ~/.ssh/id_ed25519.pub >> ~/.config/sops/age/keys.pub
```

- To obtain the `age` _public_ key from SSH Agent, run the following command:

```bash
ssh-add -L | ssh-to-age >> ~/.config/sops/age/keys.pub
```

#### Private Keys

- To obtain the `age` _private_ key for a user, run the following command:

```bash
ssh-to-age -private-key -i ~/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt
```
