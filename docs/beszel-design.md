# Beszel fleet monitoring and cache landing page

Design updated 2026-09-24 from the user's scope decision. Supersedes the alternatives in
[nix-cache-dashboard.md](nix-cache-dashboard.md). This is a design document, not a deployed service.

## Agreed scope

- Drop Cockpit and its proposed local login account. Park GoAccess.
- Add a dedicated `nixos/hosts/hub` host, with hostname `hub` and HTTPS address
  `https://hub.slopageddon.app`.
- Provide independently importable hub and agent modules, with defaults that hosts can override.
- Monitor exactly the 20 dedicated GitHub runners, S3, nix-cache and hub itself: 23 agents. Do not
  enroll other hosts.
- Keep the nix-cache HTTPS root as a cyberpunk landing page with declared system information and a
  Beszel link.
- Add timestamps to Nginx logs. Preserve binary-cache routes and behavior.

## Module structure

```text
nixos/system/config/services/beszel/
  default.nix
  hub/default.nix
  agent/default.nix
nixos/hosts/hub/
  default.nix
  installer.nix
  README.md
```

`beszel/default.nix` imports the hub and agent definitions but enables neither role. The role
modules can also be imported independently. Hosts explicitly enable `services.beszel.hub.enable` or
`services.beszel.agent.enable`.

Build on the upstream `services.beszel.*` namespace. Do not duplicate its option definitions or wrap
them in a limited settings subset. Put policy defaults behind the respective enable conditions and
use `lib.mkDefault` so normal host settings override them. Add only missing integration options:
frontend/TLS, optional secret references and managed system inventory. Separate production
endpoint/credentials from reusable module defaults.

The pinned nixpkgs packages Beszel 0.20.0 and exposes every option listed in the feedback, including
agent `extraPath`, `environment.SKIP_SYSTEMD`, SMART options, package overrides and both environment
files. These remain directly usable.
[Pinned hub module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/beszel-hub.nix),
[agent module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/beszel-agent.nix)

The new hub needs registration in both host metadata and configuration outputs in
`nixos/hosts/default.nix`. Follow the existing QEMU/cloud-init installation and secret-delivery
patterns. Enable the agent on the hub as well: the hub server alone does not collect its host's
metrics. Keep separately configured runner hosts outside this explicit 23-host scope.

### One inventory for enablement and registration

Use a small shared fleet inventory based on the existing `runnerNames` list plus `nix-cache`, `s3`
and `hub`. Each member names its assigned hub, with optional overrides for display name, address and
secret references. Feed this inventory to host construction to import/enable the agent profile, and
to hub configuration generation. This makes adding a fleet member a single declaration instead of
maintaining two independent host lists.

Importing a NixOS module affects only that host's configuration; it cannot itself mutate another
host's configuration. A flake could inspect evaluated host configurations, but that introduces
cross-host evaluation dependencies. Prefer the shared inventory as the source of truth. Reusable
agent-module imports remain possible outside this fleet; those require explicit registration with
their selected hub. Do not automatically discover or register unrelated hosts merely because they
enable a service.

The production inventory assigns all 23 members to `hub`. A future test hub can use the same modules
with its own inventory and credentials. Changes take effect when the corresponding host
configurations are deployed; adding a source entry is not runtime auto-enrollment.

## Defaults and connection model

The confirmed hostname is `hub.slopageddon.app`. Bind Beszel to `127.0.0.1:8090`, set
`APP_URL=https://hub.slopageddon.app`, and expose HTTPS through Nginx. Reuse
`services.cloudflare-acme` for Let's Encrypt certificates, Cloudflare DNS-01 validation, Opnix
credential delivery and Nginx reloads, as on S3 and nix-cache. Permit both operator and agent
networks; preserve WebSocket forwarding. Beszel documents deployment behind Nginx.
[Reverse-proxy guide](https://beszel.dev/guide/reverse-proxy)

DNS should resolve the name to the hub's reachable private address, using the existing DNS-only
approach. DNS-01 does not require opening inbound port 80. TLS private-key handling and renewal
remain with the existing NixOS ACME service rather than adding a second certificate manager to
Beszel.

Beszel also supports native automatic Let's Encrypt TLS through PocketBase's `serve` command. That
is an alternative deployment mode, not required for this design. Reusing the existing DNS-01
frontend is the consistent choice for these private hosts.
[Beszel command](https://github.com/henrygd/beszel/blob/v0.20.0/internal/cmd/hub/hub.go),
[PocketBase ACME implementation](https://github.com/pocketbase/pocketbase/blob/v0.40.4/apis/serve.go)

Prefer agents initiating connections to the HTTPS hub. Set `HUB_URL` to the HTTPS URL, disable their
SSH listener using `DISABLE_SSH=true`, and leave `openFirewall=false`. Deliver a hub public key and
per-agent token using runtime files. No new inbound agent port is needed. The hub authenticates the
agent token, and the agent checks the hub's signed challenge.
[Beszel connection security](https://beszel.dev/guide/security)

| Traffic                                           | Firewall policy                                                                    |
| ------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Browsers and agents to hub TCP 443                | Open on hub; frontend allowlist includes their networks                            |
| Nginx to Beszel TCP 8090                          | Loopback only; no external opening                                                 |
| Hub to agents TCP 45876                           | Not used with WebSocket-only agents; leave closed                                  |
| Administrative SSH TCP 22                         | Retain existing SSH policy; monitoring does not require additional SSH permissions |
| Hub outbound ACME, Cloudflare and secret delivery | Existing outbound HTTPS/DNS requirements                                           |

All hosts share the environment and can reach the hub. Monitoring needs only HTTPS in this design.
Beszel's alternative SSH transport runs from hub to the agent's dedicated listener, not from an
agent to the hub's normal SSH daemon. The hub's own agent uses the same configured HTTPS endpoint;
verify local DNS and routing permit it.

Start with systemd monitoring enabled and SMART disabled for these VMs. Keep disk selection and
additional mounts overridable. The agent's native `SKIP_SYSTEMD` option is a boolean; most other
environment entries are strings.
[Environment reference](https://beszel.dev/guide/environment-variables)

The pinned agent module automatically grants Docker-group membership on Docker-enabled hosts,
including the runners. That is service-level access to the Docker API, not permission for dashboard
viewers to administer containers. Decide whether container metrics are needed; if retained, test
that the dashboard exposes only intended inspection functions. Do not claim that a Docker socket
becomes restricted to read operations just because it is mounted read-only. SMART also adds device
access/capabilities, so keep it opt-in.
[Agent module source](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/beszel-agent.nix)

Multiple hub hosts can import the same module with independent domains, state and credentials. This
does not mean one agent reports to multiple hubs: the standard agent configuration has one outbound
`HUB_URL`. Simultaneous reporting would need separate instances and is outside the MVP.
[Pinned agent client](https://github.com/henrygd/beszel/blob/v0.20.0/agent/client.go)

## Declarative configuration versus runtime state

| Item                                                                      | Proposed owner                                                      |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Packages, services, ports, frontend, TLS, firewall and collector settings | NixOS configuration                                                 |
| Agent URL and credential file locations                                   | NixOS; secret contents delivered at runtime                         |
| Monitored systems and assigned user emails                                | Nix-generated Beszel `config.yml`                                   |
| Initial account creation                                                  | Explicit bootstrap step; UI or tested bootstrap automation          |
| Further users, roles, passwords and OAuth providers                       | PocketBase database; UI/API unless additional provisioning is built |
| Alert preferences and notification settings                               | Application state for MVP                                           |
| Metrics history, fingerprints, hub private key and application database   | Persistent runtime state; include in backups                        |

Beszel 0.20.0 reads `config.yml` from its application data directory at startup. Its schema covers
system name, host, port, token and existing-user email assignments. It does not create users. A
non-empty file removes systems absent from the inventory; changes to name/host/port can recreate
identity. An empty system list does not clear the inventory. Keep explicit user assignments and
avoid casually renaming systems.
[Pinned configuration reconciler](https://github.com/henrygd/beszel/blob/v0.20.0/internal/hub/config/config.go)

For this fixed fleet, prefer one declared inventory over universal-token auto-enrollment. The latter
is supported but should not be mixed with authoritative inventory pruning. Provision stable
per-agent tokens, render the final configuration from runtime secrets, and validate it before
publication/restart. Do not embed tokens in Nix store files. Existing database state still needs
backups: a Nix rebuild cannot reconstruct metric history.

An optional future provisioning service could reconcile users, roles, OAuth settings and alerts
through the API. That is additional code, with lifecycle and deletion semantics to design; it is not
supplied by the existing NixOS module. Keep that distinction explicit rather than calling the whole
application declarative.

## Login and read-only access

Beszel uses PocketBase accounts, not Linux/PAM users. MVP login is email and password. The initial
setup creates a dashboard account and a separate PocketBase superuser account; their credentials
subsequently have independent lifecycles. Use the superuser for application setup and separate
`readonly` dashboard accounts for routine viewing. That role can still create alerts, so it is not a
ban on all application-state changes.
[User accounts and roles](https://beszel.dev/guide/user-accounts)

`USER_EMAIL` and `USER_PASSWORD` provide initial bootstrap inputs, not continuous account/password
reconciliation. The pinned migration and UI setup paths are not identical; validate the resulting
dashboard role if automating setup. Store bootstrap credentials outside the Nix store. No `linadmin`
operating-system account is required.
[Pinned initial-settings migration](https://github.com/henrygd/beszel/blob/v0.20.0/internal/migrations/initial-settings.go)

GitHub login is supported through OAuth2; custom OIDC providers are also supported. Configure the
provider and client credentials in PocketBase, with callback `<hub-url>/api/oauth2-redirect`. Keep
automatic user creation disabled initially and assign existing viewers explicitly. Switching off
password login is an environment setting for a later rollout after OAuth works. OAuth is not needed
for MVP. [Beszel OAuth setup](https://beszel.dev/guide/oauth)

## Cache landing page

Use a Nix-built HTML/CSS page with hostname, purpose, configured architecture/system version,
upstream labels and a prominent Beszel link. Mark version details as deployed-configuration
information rather than claiming to detect the currently booted kernel. Reuse the current
near-black/cyan/magenta theme, with a compact service-card layout and no external assets.

No timer, runtime collector, capacity graph or application backend is necessary. Serve exact `/` and
dedicated static asset paths; preserve the existing regex cache routes, request methods, upstreams
and network restrictions. Remove autoindex and return 404 for unrelated paths. Keep the accepted
timestamped logging improvement even though log analytics is deferred.

Beszel covers host resource metrics and systemd service status, not Nginx cache HIT/MISS ratios or a
general Nginx log viewer. It also does not inherently distinguish cache-directory size from other
usage on the shared root filesystem. Those capabilities remain deferred with GoAccess or a future
collector. [Beszel metrics](https://www.beszel.dev/guide/what-is-beszel),
[systemd monitoring](https://beszel.dev/guide/systemd)

## Implementation inputs and checks

Before deployment, establish DNS for the agreed hub name, initial account email, management/agent
networks and secret references.

The pinned Beszel command defaults its application directory to relative `beszel_data`. The NixOS
module uses `services.beszel.hub.dataDir` as the working directory without overriding that default.
Therefore the inventory belongs at `${services.beszel.hub.dataDir}/beszel_data/config.yml`, normally
`/var/lib/beszel-hub/beszel_data/config.yml`. Back up that application directory, including the
database and hub key. Keep this relationship intact when supporting `dataDir` overrides.
[Pinned entrypoint](https://github.com/henrygd/beszel/blob/v0.20.0/internal/cmd/hub/hub.go)

Validate the hub and all 23 requested agent configurations, per-host overrides, non-default
paths/ports and disabled roles. Verify fleet membership and agent enablement agree, with no
unrelated hosts enrolled. Exercise bootstrap, role permissions, inventory reconciliation, token
authentication, restart/reconnect, certificate renewal, firewall reachability and secret
availability using a fixture. Check cache GET/HEAD and MISS/HIT behavior for all five upstreams
after changing only landing-page routes/logging. The implemented configuration and deployment
requirements are documented in [the hub README](../nixos/hosts/hub/README.md).
