# Nix download cache

`nix-cache.slopageddon.app` serves disk-backed Nginx mirrors of public Nix caches over HTTPS.
It caches downloads on demand, preserves upstream Nix signatures, and does not accept uploads.
This host is independent of the GitHub runner service and does not register a runner.

## Upstream caches

The server routes and runner settings are generated from
[`upstreams.json`](../../system/config/services/nix-cache/upstreams.json).
Each entry defines a name, upstream host, local URL prefix and upstream public signing key.

| Local URL path             | Upstream                                     |
| -------------------------- | -------------------------------------------- |
| `/`                        | `https://cache.nixos.org`                    |
| `/devenv`                  | `https://devenv.cachix.org`                  |
| `/tars-cloud`              | `https://tars-cloud.cachix.org`              |
| `/bingamon-lab`            | `https://bingamon-lab.cachix.org`            |
| `/bingamon-lab-tf-modules` | `https://bingamon-lab-tf-modules.cachix.org` |

All upstreams share the 750 GiB cache limit and 100 GiB free-space threshold.
Cache keys include the upstream host and request URI, keeping their contents separate.
Only listed upstreams are exposed; this is not an arbitrary forward proxy.
When adding a public cache, update the catalog and the matching URLs and signing keys
in `flake.nix`. Private upstreams require a separate credential and access-control design.
Deploy the cache server before upgrading clients to use new endpoints.

## Deployment inputs

- Nutanix VM: x86-64, UEFI, VirtIO storage/network, 8 vCPU, 16 GiB RAM.
- DHCP is the default; use a reservation or supply network configuration through cloud-init.
- Storage: a single 1 TiB OS disk shared by the system and download cache.
- The OS image uses filesystem labels `nixos` and `ESP`, with root growth enabled.
- Nginx stores its cache under `/var/cache/nginx` on the root filesystem; no separate disk or cache filesystem label is required.
- The cache is capped at 750 GiB, with entries unused for 30 days eligible for eviction.
- Nginx also evicts cached downloads when filesystem free space falls below 100 GiB (`min_free=100g`). This asynchronous cleanup is not a hard space reservation.
- The QEMU guest agent is enabled; expose its guest-agent channel in the VM configuration.

The disk layout and network restrictions should be confirmed before deployment.
The current HTTPS allowlist includes RFC1918 source addresses and loopback, covering routed private environments by default.
Narrow `services.nix-cache-proxy.allowedNetworks` to the actual client CIDRs, and enforce the DMZ boundaries in the network firewall.
Add any required IPv6 client prefixes explicitly.
SSH uses keys delivered by cloud-init; restrict SSH to management networks at the network firewall.

## DNS and certificate

Resolve `nix-cache.slopageddon.app` to the VM's private IP in every connected environment.
If publishing the private address in Cloudflare, use **DNS only**, not the Cloudflare proxy.
Clients need routing to that address; publishing a private address does not provide connectivity from SaaS runners.

NixOS's ACME client talks directly to Cloudflare using DNS-01 and obtains a publicly trusted Let's Encrypt certificate.
No separate acme-dns server, public VM address, or inbound Internet port forwarding is needed.
Allow outbound HTTPS to Cloudflare, Let's Encrypt, 1Password, GitHub and upstream caches, plus DNS and time synchronisation.
Certificate validation and Nginx upstream resolution use Cloudflare's public DNS resolvers to bypass internal DNS overrides.

The Cloudflare token needs `Zone:Read` and `DNS:Edit` restricted to the `slopageddon.app` zone.
The configuration requests only `nix-cache.slopageddon.app`, but the token's DNS permission is zone-wide.
There is no wildcard certificate or `.lab` SAN.
An ACME contact email has not yet been selected; NixOS supports registration without one, or set `security.acme.certs."nix-cache.slopageddon.app".email`.

The shared `services.cloudflare-acme` module retries failed certificate requests
every 15 minutes until success, then returns to daily renewal checks. Override
`services.cloudflare-acme.retryIntervalSeconds` to change this delay. Credentials
must first be available from Opnix; an Opnix dependency failure needs separate recovery.

## 1Password and cloud-init

Use the same deployment flow as the GitHub runners:

1. Cloud-init delivers the **1Password service-account token** to `/etc/opnix-token`, owned by root with mode `0600`.
2. Ensure that service account can read the `fleet` vault and the item below.
3. Opnix reads `op://fleet/Cloudflare ACME Slopageddon/token`.
4. Opnix writes the **Cloudflare API token** to `/run/secrets/cloudflare-acme-slopageddon`, owned by root with mode `0400`.
5. `acme-order-renew-nix-cache.slopageddon.app.service` waits for opnix and receives that file through systemd credentials as `CF_DNS_API_TOKEN_FILE`.
6. Nginx reloads after certificate issuance or renewal.

Neither token belongs in Git, the Nix store, the generated image, or a build log.
The controller delivers `/etc/opnix-token` before the guest starts bootstrap; opnix retries failures rather than permanently stopping when credentials are unavailable.
The ACME module may initially create a temporary self-signed certificate; do not consider deployment ready until the trusted certificate has been issued.

## Image and bootstrap

Use the [generic QEMU image](../../../docs/cloud-images.md):

```sh
./scripts/generate-cloud-image.sh qemu
```

Import `output/nixos-qemu.img` (qcow2) and enlarge the OS disk to 1 TiB.
Cloud-init supplies operator SSH keys and non-secret bootstrap
configuration selecting `nix-cache`. The controller delivers the OpNix token
outside cloud-init, the guest then resolves its configured ref and owns build, reboot and completion. No cache closure or
credentials are preloaded. The `installer-nix-cache` output is a compatibility
entry point producing the generic image in raw format.

The final host's auto-upgrade source is configured in `default.nix`; it switches
configurations without automatic reboots.

```sh
journalctl -b -u nixos-bootstrap.service
```

## Clients and fallback

The dedicated GitHub runners import `nixos/system/config/services/nix-cache/client.nix`.
Other connected NixOS hosts can import the same file.
It prefers the local URLs with `priority=10`, retains every upstream URL for fallback, and sets a five-second connection timeout.
The timeout applies per connection attempt, not to the total duration of retries or stalled transfers.
Signature checks remain enabled, with the public signing keys of all listed upstreams; the proxy needs no signing key.

The repository-wide `nixConfig` also prefers these endpoints and sets a five-second connection timeout.
Commands accepting the flake configuration will try it, including on Googong and SaaS runners;
where private DNS or routing is unavailable, they must fall back to the retained public caches.
Use `--accept-flake-config` to accept these settings non-interactively.
The cache host itself does not import the client module, but flake commands accepting `nixConfig`
will also try its proxy; public caches remain available during bootstrap and maintenance.
Cache-to-cache failover does not require enabling Nix's `fallback` setting, which allows source builds after substitution failures.

## Validation and operations

Local validation completed on 2026-09-21:

- All 20 dedicated runners, JONS, the cache host and installer evaluated with no failed assertions; the cache image derivation also evaluated.
- Generated Nginx configuration built successfully and passed `nginx -t` with local fixture certificates and paths.
- Changed-file pre-commit hooks passed.
- Evaluated ACME renewal dependencies and systemd credential delivery match the opnix secret reference.
- A local HTTPS upstream fixture verified MISS/HIT behaviour, metadata matching, HEAD requests, method restrictions, concurrent cache locking and uncached 404 responses.
- Nix 2.34.8 downloaded a signed store path through the proxy and rejected an incorrect signing key.
- Separate client stores used a second HTTPS substituter after DNS failure, connection refusal, an unresponsive TLS endpoint and an interrupted archive download.
- Source-build fallback remained disabled during these failover tests.
- Both runner groups have 10 members, all dedicated runners have the cache and Bubblewrap enabled, and JONS's runner remains disabled.

The runtime fixture used local ports and a test CA; it did not request a real certificate or contact 1Password.
The deployed VM has booted and expanded its root filesystem to 1 TiB.
Before rollout, verify delayed credential delivery and real certificate issuance/renewal.
Also verify stale serving during upstream outages and connectivity/fallback from each deployed environment.

Inspect `X-Cache-Status` response headers and `/var/log/nginx/nix-cache-access.log` for cache activity.
Metadata is refreshed sooner than immutable archives; entries may be evicted independently, so the cache is an accelerator rather than a guaranteed offline mirror.
Cache size enforcement is asynchronous; retain filesystem headroom for active downloads and eviction.
Back up configuration, secret references and `/var/lib/acme`; cached downloads under `/var/cache/nginx` are rebuildable and need not be backed up.

```sh
systemctl status opnix-secrets acme-order-renew-nix-cache.slopageddon.app nginx
journalctl -u acme-order-renew-nix-cache.slopageddon.app
curl -I https://nix-cache.slopageddon.app/nix-cache-info
```
