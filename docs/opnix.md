# 1Password Secret Management with OpNix

This document outlines how secrets are managed in this Nix flake using **OpNix** (`github:brizzbuzz/opnix`) and the **1Password CLI (`op`)**.

---

## 1. Bootstrapping a New Machine using `nixos-anywhere`

Nix builds are pure and offline; they cannot contact the 1Password API at build time.
Instead, the 1Password Service Account token must be present on the target machine's filesystem at boot time so that the systemd `onepassword-secrets.service` can retrieve the secrets.

To handle this "chicken-and-egg" bootstrapping problem, provision the token using `nixos-anywhere`'s `--extra-files` flag:

1. **Prepare the Token Locally**:
   On your deployment machine, create a temporary directory structures mirroring the target host:

   ```bash
   # Create a secure temporary directory
   temp=$(mktemp -d)

   # Recreate the target path structure
   mkdir -p "$temp/etc/opnix"

   # Save the 1Password Service Account Token
   echo "your-1password-service-account-token" > "$temp/etc/opnix/token"
   chmod 400 "$temp/etc/opnix/token"
   ```

2. **Run `nixos-anywhere`**:
   Deploy to the target host and copy the token before boot:

   ```bash
   nixos-anywhere --extra-files "$temp" --flake .#HOSTNAME root@TARGET_IP

   # Clean up local temporary files
   rm -rf "$temp"
   ```

Upon first boot, the target machine will have the token pre-installed at `/etc/opnix/token`, allowing systemd to decrypt and mount the required secrets.

---

## 2. Managing Secrets in 1Password using the `op` CLI

All secrets for the fleet are housed in a single 1Password vault named **`fleet`**.
You can create the required items and custom fields directly from the command line using the assignment syntax `label[type]=value`.

### Create Test Secret

To create a test secret:

```bash
op item create --category "Secure Note" --title "TestSecret" --vault "fleet" "value[Text]=my-secret-test-value"
```

- **Reference URI**: `op://fleet/TestSecret/value`

### Create Incus ACME DNS Secret

To create the Incus DNS token configuration (stored as an environment file fragment):

```bash
op item create --category "Secure Note" --title "Incus" --vault "fleet" \
  "acme-env[Text]=CLOUDFLARE_DNS_API_TOKEN=\"your-cloudflare-dns-token\""
```

- **Reference URI**: `op://fleet/Incus/acme-env`

### Create DaisyUI CLI Credentials

To create DaisyUI email and license credentials:

```bash
op item create --category "Login" --title "DaisyUI" --vault "fleet" \
  "email[Text]=user@example.com" \
  "license[Concealed]=your-license-key"
```

- **Reference URIs**:
  - Email: `op://fleet/DaisyUI/email`
  - License: `op://fleet/DaisyUI/license`

---

## 3. Adding New Secrets into the Nix Flake

OpNix supports secrets at both the **system level (NixOS)** and **user level (Home Manager)**.

> [!IMPORTANT]
> **Validation Constraint**: OpNix requires secret configuration keys to be written in **camelCase** (e.g. `mySecretName`, not `my-secret-name`).

### System-Wide Secrets (NixOS)

To add a system-level secret:

1. Open [nixos/system/soe/secrets/opnix.nix](file:///boot/nixos/nix-config/nixos/system/soe/secrets/opnix.nix).
2. Declare your secret under the `secrets` attribute set:
   ```nix
   services.onepassword-secrets.secrets = {
     myNewSecret = {
       reference = "op://fleet/VaultItemName/FieldName";
       path = "/run/secrets/my-new-secret"; # Path where secret is mounted
       owner = "root";                      # UNIX file owner
       group = "root";                      # UNIX file group
       mode = "0400";                       # File permissions
       services = [ "my-service.service" ]; # Restart these systemd units when secret changes
     };
   };
   ```

### User Secrets (Home Manager)

To add a user-level secret:

1. Open [home/nix/secrets/opnix.nix](file:///boot/nixos/nix-config/home/nix/secrets/opnix.nix).
2. Declare your secret under the `secrets` attribute set:
   ```nix
   programs.onepassword-secrets.secrets = {
     myUserSecret = {
       reference = "op://fleet/VaultItemName/FieldName";
       path = ".config/my-secret-file";     # Path relative to home directory
       mode = "0600";
     };
   };
   ```

---

## 4. Verifying Secrets on NixOS

Once the configuration has been rebuilt (`sudo nixos-rebuild switch --flake .#HOSTNAME`), verify that the secrets have successfully resolved:

1. **Verify Token & OpNix Daemon**:
   Verify that the 1Password Secrets daemon started successfully:

   ```bash
   systemctl status onepassword-secrets.service
   ```

2. **Verify Secret Resolution**:
   Check if the decrypted files are successfully mounted in memory (`tmpfs` / `ramfs`):
   - **System-wide**:
     ```bash
     sudo cat /run/secrets/incus-acme.env
     ```
   - **Home Manager**:
     ```bash
     cat ~/.config/daisyui/email
     cat ~/.config/daisyui/license
     ```

If a secret fails to resolve, check the system logs for error details:

```bash
journalctl -u onepassword-secrets.service
```
