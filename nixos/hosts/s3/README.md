# Internal S3 cache

This host runs RustFS with an internal S3 API at `https://s3.slopageddon.app`
and the authenticated web console at `https://s3-console.slopageddon.app`.
It stores disposable CI caches, not durable release artifacts or backups.

The host also runs a Beszel agent reporting to `https://hub.slopageddon.app`.
Its additional Opnix references are listed in the [hub setup](../hub/README.md).
Monitoring uses outbound HTTPS and does not change S3 API or console routes.

## Deployment

Use the existing generic QEMU image and guest-owned bootstrap process described in
[cloud-images.md](../../../docs/cloud-images.md), selecting flake host `s3`.
The bootstrap prerequisite is `/etc/opnix-token`, delivered outside cloud-init.
The 1Password service account must be able to read the `fleet` items listed below.
No secret value belongs in user-data, Git, a Nix expression, or the Nix store.

The host imports the existing UEFI/QEMU guest configuration. Allocate a single virtual
OS disk (for example 150 GB or 1 TB). The root partition and ext4 filesystem grow
on boot to the available virtual disk size. After increasing that disk in the
hypervisor, reboot to apply growth. Disk growth does not allocate more hypervisor
storage automatically and does not change RustFS's single-node, single-volume topology.
Data lives under `/var/lib/rustfs` on root. No extra disk label is required.

Create DNS-only Cloudflare records for both hostnames pointing at the VM's internal IP.
ACME uses Cloudflare DNS-01 and a public DNS resolver; inbound Internet access is
unnecessary. Outbound access to 1Password, Cloudflare, Let's Encrypt and Nix sources
is required. Only HTTPS port 443 is opened for the service; RustFS API/console ports
9000/9001 bind to loopback. Nginx permits RFC1918 and loopback clients by default.
Narrow `frontend.allowedNetworks` to the routed client/management networks if needed.
The existing SSH configuration accepts keys supplied through cloud-init.

The console is available at `/rustfs/console/` on its hostname. Log in using the
administrator access key and secret key from 1Password.

## Credentials

All items are in the `fleet` vault:

| Item                            | Fields                     | Purpose                                     |
| ------------------------------- | -------------------------- | ------------------------------------------- |
| `RustFS S3 Admin`               | `access_key`, `secret_key` | Server administrator and provisioning       |
| `RustFS GitHub Actions Writer`  | `access_key`, `secret_key` | Read/list/write/delete in `github-actions`  |
| `RustFS GitHub Packages Writer` | `access_key`, `secret_key` | Read/list/write/delete in `github-packages` |
| `Cloudflare ACME Slopageddon`   | `token`                    | Certificates for both hostnames             |

Opnix writes root-owned runtime files with mode 0400. systemd delivers private
credential copies to RustFS and the provisioning service. Application secrets are
never command-line arguments. CI receives its writer credential separately; do not
use the administrator identity in workflows.

After updating an item, restart `opnix-secrets.service` to fetch it. Opnix restarts
consumers when their secrets change. A root credential change requires a RustFS
restart; writer credential changes are applied by `rustfs-provision.service`.
Coordinate writer-secret changes with CI because the old secret stops working.
Changing a managed access key disables its old identity; removing a writer disables
its previously managed identity. The root-owned provisioning state under
`/var/lib/rustfs-provision` records key IDs and secret fingerprints, never secret values.
Preserve this state when retaining the RustFS data directory so removed identities
can still be identified and revoked.

## Buckets and retention

Both initial buckets allow anonymous **object reads**, but no anonymous listing,
write, delete or administrative operations. This means any client with network
access and an object URL can read the content. Writer identities are independent
and restricted to their own buckets, including multipart operations.

| Bucket            | Object expiration | Abandoned multipart uploads |
| ----------------- | ----------------- | --------------------------- |
| `github-actions`  | 30 days           | 1 day                       |
| `github-packages` | 30 days           | 1 day                       |

Lifecycle expiration is based on object age, not last read time, and runs
asynchronously. Noncurrent versions also expire if versioning is enabled later.
Versioning is not enabled by this module. Thirty days is **not a disk-size limit**:
monitor root free space and shorten retention or enlarge the disk before it fills.
RustFS has no Nginx-style `min_free` configuration supplied by this module.

The bucket name `github-packages` does not implement the GitHub Packages protocol.
It is an ordinary S3 bucket. Existing `actions/cache` workflows also do not switch
to it automatically; use an S3-capable cache action and path-style addressing.
For AWS-compatible clients use region `us-east-1`, the API endpoint above, and
path-style requests such as `/github-actions/object-key`.

## Reusable modules

The host file only selects shared infrastructure and declares service policy:

- `nixos/system/config/services/rustfs/default.nix`: RustFS settings and bucket/user reconciliation.
- `rustfs/opnix.nix`: optional 1Password credential delivery.
- `rustfs/frontend.nix`: optional internal Nginx API and console frontends.
- `cloudflare-acme/default.nix`: reusable Cloudflare DNS-01/Opnix integration.

Failed certificate requests retry every 15 minutes until successful. Configure
`services.cloudflare-acme.retryIntervalSeconds` to change the delay. Successful
requests return to the normal daily renewal schedule and reload Nginx. This
recovers from transient network/API failures; invalid credentials still require
correction. Dependency failures before the ACME process starts are not covered
by its restart policy; inspect `opnix-secrets` if credentials are unavailable.

Add a bucket under `services.rustfs-managed.buckets`, setting `publicRead` (default
false), `retentionDays` (default 30) and optionally `abortMultipartDays` (default 1).
Add a writer with its permitted bucket names and runtime credential-file paths,
or declare its 1Password item under `opnix.writerItems`.

Bucket policies and lifecycle rules for declared buckets are owned by this module;
console edits to those settings are replaced on reconciliation. Writer policy
mappings are replaced rather than accumulated, so reducing grants takes effect.
The service runs at startup, after configuration changes, and every 15 minutes.
The timer also retries provisioning after unavailable credentials or failed starts.

Removing a bucket declaration **never deletes the bucket, objects, existing policy
or lifecycle rules**. To revoke anonymous access, declare `publicRead = false` and
apply that change before removing the declaration. Unmanaged users are untouched.
Do not reuse a managed writer identity for unrelated policies or groups.

## Upgrades and future availability

The host inherits nightly upgrades at 03:00 plus up to one hour of random delay,
with catch-up after missed runs. It follows `github:MAHDTech/nix-config#s3`, switches
configuration, and does not automatically reboot. Changed services may restart.
The current Nixpkgs pin supplies RustFS `1.0.0-rc.6`. Writer reconciliation uses its
admin API, so rerun the integration test when updating RustFS/Nixpkgs.
Caches can be discarded and repopulated if an application upgrade needs recovery;
a NixOS rollback is not a guarantee of an on-disk format rollback.

This is deliberately a single-node, single-volume deployment without replication.
Future HA requires a separately tested distributed layout and load balancer.
Do not assume that adding nodes converts this volume into a cluster in place.
Replication/versioning would also require revisiting lifecycle rules and IAM ownership.

## Verification

```sh
systemctl status rustfs rustfs-provision nginx
systemctl --failed
journalctl -u rustfs-provision -u rustfs
systemctl list-timers rustfs-provision.timer nixos-upgrade.timer
curl --fail https://s3.slopageddon.app/health/ready
curl --fail https://s3-console.slopageddon.app/rustfs/console/
df -h /var/lib/rustfs
```

An anonymous GET of the S3 root may correctly return AccessDenied. Upload a disposable
object with the bucket writer credentials, verify anonymous object download works,
and verify anonymous PUT/list and cross-bucket writes fail. Also test your actual
CI cache action, including archive restore, save and multipart uploads.

Local validation uses `tests/test_rustfs_integration.py` with generated fixture
credentials and disposable RustFS storage. It checks repeated provisioning, public
and private access, bucket isolation, multipart uploads, policy/retention changes,
secret/access-key rotation, removed-writer revocation, and preservation of removed
buckets. Optional Nginx arguments exercise the generated HTTPS proxy using a test CA.
The test does not contact 1Password or request real certificates, and does not wait
30 days to observe lifecycle deletion.

A disposable UEFI/QEMU VM also bootstrapped from the generic image into this host
configuration with fixture credential delivery and external integrations disabled.
RustFS started with systemd credentials, both buckets and writers reconciled,
no units failed, and the root filesystem grew to the allocated 24 GB disk.
Production DNS, 1Password access and ACME issuance still need deployment validation.
