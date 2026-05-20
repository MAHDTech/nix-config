# Deploying with nixos-anywhere and 1Password

When deploying NixOS via `nixos-anywhere` from a machine that uses 1Password for SSH key management, you will likely encounter SSH authentication errors such as `Too many authentication failures`.

This happens because the 1Password SSH Agent aggressively offers all available keys in your vault to the target host.
By default, SSH servers drop connections after 6 failed key attempts (`MaxAuthTries`), which occurs before `nixos-anywhere` can negotiate its connection.

### The Solution

To bypass 1Password and successfully deploy, you must force `nixos-anywhere` to completely ignore the SSH agent and use a specific private key file from your local disk.

1. Ensure the public key corresponding to your local private key (e.g., `~/.ssh/id_ed25519.pub`) is present in the `~/.ssh/authorized_keys` file on the target machine.
2. Run `nixos-anywhere` with the following environment variables and SSH options:

```bash
env SSH_AUTH_SOCK="" nix run github:nix-community/nixos-anywhere -- \
  --flake .#<HOSTNAME> \
  --build-on remote \
  -i ~/.ssh/id_ed25519 \
  --ssh-option "IdentitiesOnly=yes" \
  --ssh-option "IdentityAgent=none" \
  nixos@<TARGET_IP>
```

### Explanation of Flags:

- `env SSH_AUTH_SOCK=""`: Hides the active SSH agent socket from the shell environment.
- `--ssh-option "IdentityAgent=none"`: Overrides any `IdentityAgent` directives in your `~/.ssh/config` (where 1Password usually hooks in), preventing it from hijacking the connection.
- `--ssh-option "IdentitiesOnly=yes"`: Forces the SSH client to _only_ attempt authentication using the key explicitly provided.
- `-i ~/.ssh/id_ed25519`: Specifies the exact local private key file to use.
- `--build-on remote`: (Optional but recommended for cross-architecture deployments) Forces the closure to be built on the target machine's CPU architecture instead of your local machine.
