# Slopageddon mirror

`mirror.slopageddon.app` serves local software and installation artifacts through
a native Caddy service. Content is available only over HTTPS to private client
networks. The host can reach the internet for certificates and administrative
downloads. No automated content synchronization is configured.

## VM and deployment

Match nix-cache: x86-64 Nutanix VM, UEFI, VirtIO storage/network, 8 vCPU, 16 GiB
RAM and a single 1 TiB disk. Use the existing QEMU bootstrap image, enlarge the
disk and adopt `github:MAHDTech/nix-config#mirror` through the normal cloud-init
workflow. The `nixos` root filesystem expands automatically; `/srv/mirror` shares
that filesystem. `installer-mirror` is the raw bootstrap image compatibility
output, not an image with the final mirror configuration already activated.

Use DHCP with a reservation or supply networking through cloud-init. Resolve
`mirror.slopageddon.app` to the VM's private IP. Cloudflare records must be
**DNS only**. Port 443 serves downloads; there is no port 80 listener or HTTP
redirect. Narrow `services.mirror.allowedNetworks` to client CIDRs if required;
the defaults allow RFC1918 IPv4 and loopback. Supply routed IPv6 ranges explicitly.

Certificates use the shared Cloudflare DNS-01 ACME module with the token at
`op://fleet/Cloudflare ACME Slopageddon/token`. The certificate belongs to group
`caddy`, and renewal reloads Caddy. No custom Caddy DNS plugin is needed.

To enroll this host in Beszel once deployed, prepare
`op://fleet/Beszel Agents/mirror` and the existing Beszel hub public-key reference
using the same onboarding procedure as nix-cache, then add `"mirror"` to `fleet.nix`.

## Web interface

The landing page at `/` shares nix-cache's CSS, fonts and colors. The top-right
**Browse files** link opens `/browse/`, a Caddy listing of the collections.
Listings use the same CSS and a custom Caddy template. Root-listing links point
to canonical collection paths; `/browse/` does not introduce another download
namespace. The hub card remains available for host monitoring.

Disk statistics are sampled by `mirror-summary.timer` every 15 minutes and
shortly after boot. The collector runs as Caddy with read-only content access.
Filesystem capacity is measured directly; the content-size scan has a 30-second
timeout. Unavailable values and stale snapshots are identified on the page.
Mirror files are not automatically evicted to free space.

## Content layout and migration

```text
/srv/mirror/
├── nutanix/
│   ├── lcm/release/
│   ├── nkp/
│   ├── bundles/
│   ├── images/
│   └── ova/
├── f5/
│   ├── packages/
│   ├── images/
│   └── ova/
├── terraform/registry.opentofu.org/
├── iso/
├── images/
├── ubuntu/
└── redhat/
```

Ubuntu and Red Hat directories are placeholders, not configured package mirrors.
The directories are created with owner `root` and mode `0755`. Use the
cloud-init administrative SSH account and sudo for host-to-host rsync. Normalize
copied ownership and permissions so Caddy can read, but cannot modify, content:

```sh
# Run on the old host, using an SSH key accepted by the new VM.
rsync -rtv --info=progress2 --chmod=D755,F644 \
  --rsync-path='sudo -n rsync' \
  /caddy/site/release/ ADMIN@mirror.slopageddon.app:/srv/mirror/nutanix/lcm/release/
```

Replace `ADMIN` with the deployed administrative account. The destination
account needs non-interactive sudo for this command. Review executable files
before using them after copying; the example gives served files mode `0644`.
Do not use `--delete` across collections.

| Old content                           | Destination beneath `/srv/mirror/`                       |
| ------------------------------------- | -------------------------------------------------------- |
| `release/`                            | `nutanix/lcm/release/` (preserve the entire subtree)     |
| `nutanix/bundles/`                    | `nutanix/bundles/`                                       |
| `nutanix/nkp/`                        | `nutanix/nkp/`                                           |
| `f5/`                                 | `f5/packages/`                                           |
| Nutanix files in `images/` and `ova/` | `nutanix/images/` and `nutanix/ova/`                     |
| F5 files in `images/` and `ova/`      | `f5/images/` and `f5/ova/`                               |
| Other `images/`, `iso/` files         | `images/` and `iso/`                                     |
| `terraform/`                          | `terraform/` (preserve registry namespaces and metadata) |

The initial migration deliberately keeps all of `release/` together, including
its extracted NKP bundles. Further organization must preserve any manifest
references. The separate `nutanix/nkp/` tree receives the old tree of that name.

Configure Nutanix LCM for HTTPS with this dark site URL:

```text
https://mirror.slopageddon.app/nutanix/lcm/release/
```

There is no legacy `/release/` alias. Migrate consumers explicitly. OpenTofu's
provider mirror URL becomes `https://mirror.slopageddon.app/terraform/`.
Preserve the patched Nutanix provider and its checksum metadata from the old
mirror; do not regenerate that provider from upstream during migration.

Validate browsing, a large download, a resumed download, OpenTofu initialization
and a Nutanix LCM inventory before retiring the old server.

## Operations

```sh
systemctl status caddy mirror-summary
systemctl list-timers mirror-summary.timer nixos-upgrade.timer
journalctl -u caddy -u mirror-summary
curl -I https://mirror.slopageddon.app/nutanix/lcm/release/master_manifest.tgz
```

Access logs use Caddy's default journald output. Caddy serves content read-only;
uploads happen through SSH/rsync. Browsing returns file listings even if a
collection contains an HTML index file.
