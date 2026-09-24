# Beszel monitoring hub

`https://hub.slopageddon.app` provides Beszel metrics and history for the twenty
dedicated GitHub runners, `nix-cache`, `s3`, and `hub` itself. There are 23 agents.
Cockpit and GoAccess are not installed. Dashboard users are Beszel accounts;
there is no additional Linux login account.

## Deployment

Use the [generic QEMU image](../../../docs/cloud-images.md) and bootstrap host
`hub`. The `installer-hub` flake output also produces the generic raw image.
Follow the existing cloud-init and `/etc/opnix-token` delivery process.
Choose VM storage to suit the desired metrics retention, and back up the hub's
state. Unlike the download cache, this database contains history that cannot be
reconstructed by rebuilding NixOS.

Create a DNS-only record for `hub.slopageddon.app` pointing to its private IP.
Agents and browsers must be able to resolve and reach it, including the hub itself.
Nginx listens on HTTPS port 443 and proxies WebSockets to Beszel on
`127.0.0.1:8090`. The existing Cloudflare DNS-01 module obtains and renews a
Let's Encrypt certificate. No inbound Internet access or port 80 is required.
Outbound DNS and HTTPS access to 1Password, Cloudflare and Let's Encrypt is required.

The default frontend allowlist permits RFC1918 and loopback addresses. Override
`services.beszel.hub.frontend.allowedNetworks` to narrow it or add routed IPv6
networks. Agents initiate HTTPS connections; their Beszel SSH listeners are
disabled and port 45876 remains closed. Administrative SSH retains its existing
key-based policy.

## Required 1Password items

Create these items in the `fleet` vault before deploying the agents. Values must
only be stored in 1Password and delivered by Opnix, never pasted into Nix files,
Git, cloud-init user-data or command arguments used for builds.

| Item                          | Field                   | Value                                                                                    |
| ----------------------------- | ----------------------- | ---------------------------------------------------------------------------------------- |
| `Beszel Hub`                  | `private_key`           | An unencrypted OpenSSH Ed25519 private key, preserving line breaks and the final newline |
| `Beszel Hub`                  | `public_key`            | Its matching OpenSSH public key                                                          |
| `Beszel Hub`                  | `bootstrap_environment` | Multiline systemd environment file described below                                       |
| `Beszel Agents`               | One field per host      | A different random registration token for each of the 23 hosts                           |
| `Cloudflare ACME Slopageddon` | `token`                 | Existing DNS-01 token; reuse the current item                                            |

The agent field names are `github-runner-01` through `github-runner-20`,
`nix-cache`, `s3` and `hub`. Generate each token independently with your password
manager, using at least 32 random URL-safe characters without whitespace.

Generate the key pair on a trusted administrator machine, then store both files
in the fields above and securely remove the temporary local copy:

```bash
umask 077
ssh-keygen -t ed25519 -N '' -C beszel-hub -f ./beszel-hub-key
```

`bootstrap_environment` contains these two entries, populated in 1Password with
your chosen email and a strong generated password:

```text
USER_EMAIL="your administrator email"
USER_PASSWORD="your generated password"
```

Use a URL-safe generated password to avoid environment-file quoting ambiguities.
These are placeholders describing the field format, not supplied credentials.
No shell expansion occurs. Use the same email consistently: it assigns the
declared systems to the bootstrap dashboard account on each hub start.

The hub service account needs access to all these fields. Each agent's service
account needs `Beszel Hub/public_key` and its own `Beszel Agents/<hostname>` field
in addition to its existing secrets. In particular, the Bingamon runner service
accounts must also be able to read the required `fleet` items. Opnix materializes
only the fields referenced by that host. Vault-level access may be broader than
these per-host references; configure 1Password permissions accordingly.

Files under `/run/secrets` are root-owned and mode 0400. The hub restores a missing
final newline on the private key before validating it with OpenSSH.
Systemd passes agent tokens and keys through `LoadCredential`; the hub's bootstrap environment file
is read by systemd. The hub prepares its inventory from credentials immediately
before starting, with mode 0600. The Nix store contains references and field names,
not credential values. Missing or invalid credentials prevent startup rather than
creating an unauthenticated monitoring endpoint.

## Initial login and viewers

The first database migration uses `USER_EMAIL` and `USER_PASSWORD` to create
separate dashboard and PocketBase superuser accounts. These bootstrap inputs do
not reset existing passwords on subsequent starts.

1. Log into `https://hub.slopageddon.app/_/` with the bootstrap credentials.
2. In the `users` collection, set the bootstrap dashboard account's role to
   `admin`. Beszel 0.20's environment-based migration does not set this role.
3. Create routine viewer accounts with role `readonly` and `verified=true`.
   They do not need PocketBase superuser accounts.
4. Assign those emails declaratively through `services.beszel.hub.systems.<name>.users`
   and deploy the hub. Include the administrator email if it should retain access.
   Assignments made only in the UI will be replaced by the generated inventory.
5. Log into the normal hub URL using a viewer account.

Read-only viewers can view assigned systems and create their own alerts; they
cannot create/delete systems or administer the monitored machines. Container
details/logs are disabled on this hub. Agents on Docker hosts retain upstream
Docker metrics access, which gives the agent process access to the Docker socket.
That is distinct from viewer permissions.

GitHub OAuth2 can be configured later in PocketBase using callback
`https://hub.slopageddon.app/api/oauth2-redirect`. Automatic account creation is
disabled. Keep routine accounts explicitly assigned the read-only role. OAuth
client secrets should also be stored in 1Password when that integration is added.

## Inventory, overrides and state

[`../fleet.nix`](../fleet.nix) is the shared inventory. Host construction enables
the agent for its members, and the hub generates the same list. Adding a member
requires its token field in 1Password and deployment of both host and hub. No
runtime discovery registers unrelated hosts.

The reusable modules are under
[`../../system/config/services/beszel`](../../system/config/services/beszel).
Importing their root enables neither role; set the native hub/agent `enable`
option on the intended host. The fleet profile supplies the production URL and
secret references. Another hub can import the same modules with different inputs.

All upstream NixOS options remain usable, including package/data-directory/port
overrides, `environmentFile`, `extraPath`, `environment.SKIP_SYSTEMD` and SMART
configuration. Policy defaults use `mkDefault`; SMART is off for these VMs.
The agent environment uses string values except the native boolean `SKIP_SYSTEMD`.
An agent has one outbound hub; simultaneous reporting to a test hub needs a
separate instance rather than a list of URLs.

Runtime state is `/var/lib/beszel-hub/beszel_data`, including `data.db`,
`id_ed25519` and generated `config.yml`. If `services.beszel.hub.dataDir` changes,
the `beszel_data` child follows it. Back up the full application directory using
Beszel's backup facility or a consistent backup while the hub is stopped.
Token/key changes in Opnix restart affected services; coordinate key-pair rotation
across hub and agents. Replacing a VM may require resetting its bound fingerprint
in Beszel before the replacement can connect.

The inventory is authoritative on hub startup. Removing a member deletes its
system record and can lose associated history. Renaming a member or changing its
host/port can recreate its identity. Keep stable names. Empty inventories are
rejected because upstream does not interpret them as removing all systems.

## Verification and operations

```bash
systemctl status opnix-secrets beszel-hub beszel-agent nginx
journalctl -u beszel-hub -u beszel-agent
curl --fail https://hub.slopageddon.app/api/health
```

The repository's NixOS VM check exercises the real hub, agent, systemd credential
delivery, custom port/state directory, HTTPS frontend and reconnection. It mocks
only external 1Password delivery and ACME issuance with runtime test credentials:

```bash
nix build .#checks.x86_64-linux.beszel
```

`tests/test_beszel.py` additionally exercises password login and viewer API access
against the actual Beszel binary. No test contacts production 1Password or issues
a real certificate. After deployment, verify trusted certificate issuance and
renewal, all 23 systems online, viewer permissions and the backup/restore process.
