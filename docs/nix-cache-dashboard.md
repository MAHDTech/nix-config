# Nix cache dashboard design

<!-- cspell:ignore dockermanager keepalive checkpointing sparkline sparklines -->

Superseded by [Beszel fleet monitoring and cache landing page](beszel-design.md): Cockpit is
dropped, GoAccess is parked, and the cache root becomes a static landing page. The material below is
retained as prior research, not the current implementation scope.

Research date: 2026-09-24. Proposal only; no service configuration changes.

Build a small, read-only operations landing page at `https://nix-cache.slopageddon.app/`. A systemd
timer generates a complete static HTML snapshot hourly. Nginx serves it alongside the existing
binary-cache routes. The revised direction below separates this page from live traffic analytics and
host inspection; the original detailed snapshot design follows as reference.

## Revised direction: landing page, live traffic and host inspection

Following discussion, prefer three independent components. This supersedes putting all traffic
charts and logs into the hourly page.

| Component              | Address                                     | Responsibility                                                                    |
| ---------------------- | ------------------------------------------- | --------------------------------------------------------------------------------- |
| Cyberpunk landing page | `/` on existing HTTPS listener              | Host identity, uptime, disk/cache capacity, snapshot timestamp and navigation     |
| Live GoAccess report   | `/logs/`, with `/logs/ws` for its WebSocket | Near-real-time HTTP traffic, cache outcomes, response codes and request durations |
| Host inspection        | Separate host port, or monitoring hub       | CPU, memory, disks, service state and possibly system journal                     |

The landing page should label links by purpose: **Live traffic**, **Host metrics**, and **System
journal** if available. Retain the existing cyan/magenta palette, compact capacity bars and local
assets. Do not duplicate GoAccess's charts in a custom application.

### Live GoAccess is modest integration work

The flake's pinned nixpkgs revision `4975466d324710c576dc11ad614684e6bd8cad8e` packages GoAccess
1.12, but its NixOS module list has no GoAccess service module. A local reusable module can wrap the
package rather than implementing analytics.
[Pinned package](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/pkgs/by-name/go/goaccess/package.nix),
[module list](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/module-list.nix)

Run GoAccess continuously as an unprivileged systemd service reading the timestamped access log.
Serve its generated HTML through Nginx at `/logs/`; redirect exact `/logs` there. Bind its WebSocket
server to loopback and proxy exact `/logs/ws`, advertising `wss://nix-cache.slopageddon.app/logs/ws`
to browsers. Both routes inherit the site's access restrictions; no additional public port is
required. Forward WebSocket upgrade headers and configure connection timeout/keepalive behavior.
[Nginx WebSocket proxying](https://nginx.org/en/docs/http/websocket.html)

GoAccess supports live HTML, WebSocket URLs with proxy paths, JSON log formats, cache-status `%C`,
and custom CSS. This produces live aggregate charts/tables, **not a raw scrolling log tail**, and
does not parse the system journal or Nginx error log into an incident console. Validate the shared
JSON schema against the pinned version.
[GoAccess 1.12 configuration](https://github.com/allinurl/goaccess/blob/v1.12/config/goaccess.conf)

A deliberately narrow `web-analytics` module would accept a virtual host, input log/format, URL
prefix, title, stylesheet and retention settings. It owns the service, restricted log access,
state/output directories and Nginx report/WebSocket routes. Keep timestamps/log formatting in the
webserver configuration. Start with one report per host; only introduce named instances when a
second report is needed.

The implementation effort is mostly rotation, restart/persistence, retention, reconnects and route
validation. Filter dashboard/WebSocket requests out of the input; suppress client details/query
strings in displayed output. A completed-request log cannot show an in-progress NAR transfer before
it finishes.

If a literal live log tab is required, the smaller alternative to a streaming service is a bounded,
sanitized recent-event JSON file refreshed every 5–10 seconds and polled by the browser. Label it
near-live and display freshness. It needs a separate cheap collector from the hourly disk scan, but
no browser shell or unrestricted file endpoint. Cockpit's journal page can cover systemd journal
entries, not automatically the current file-based Nginx access/error logs.

### Cockpit: limited privileges are not strict read-only

Cockpit authenticates into a Linux user session and inherits that user's permissions. An
unprivileged account can still execute programs, write its own files and manage its own processes.
Removing `wheel` membership is therefore insufficient to promise a read-only console. System service
actions also depend on Polkit, not just sudo.
[Cockpit privileges](https://docs.cockpit-project.org/cockpit-guide/main/guide/privileges.html)

For trusted operators who accept a restricted user session, a shared module could create `linadmin`
without sudo, privileged groups or Nix trusted-user membership; grant journal reading if intended;
and explicitly deny administrative Polkit actions. Disable Cockpit's privileged bridges and hide
unnecessary pages. Hiding the terminal is a presentation choice, not a security boundary. A Cockpit
maintainer documents the privileged-bridge override, but it does not remove ordinary user
capabilities. [Upstream guidance](https://github.com/cockpit-project/cockpit/discussions/21036)

This profile must be called **restricted Cockpit**, not guaranteed read-only Cockpit. If “no
changes” is a hard requirement, prefer a monitoring service exposing only the intended read
operations rather than giving the viewer a host login session. Validate actual privileges before
extending either choice across the fleet.

The pinned NixOS module supports the options listed in the discussion, including plugins and
port 9090. `allowed-origins` is browser-origin configuration, not a network ACL. Keep firewall
access restricted to management networks and configure HTTPS certificates for each host; changing
the port does not inherit the cache site's Nginx access rules.
[Pinned Cockpit module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/cockpit.nix)

An important packaging limitation: Cockpit 366 in this flake is built with `--disable-pcp`. Upstream
falls back to internal metrics without PCP, but historical archival features are unavailable. Do not
promise historical CPU/memory graphs merely from enabling Cockpit.
[Pinned package](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/pkgs/by-name/co/cockpit/package.nix),
[Cockpit PCP support](https://docs.cockpit-project.org/cockpit-guide/main/guide/feature-pcp.html)

The pinned source contains `cockpit-podman`, `cockpit-machines`, `cockpit-files`, `cockpit-zfs` and
`cockpit-dockermanager` packages. These are management integrations, not a universal read-only role.
Start with no extra plugins for this requirement. Files/containers/VM management would add
interfaces to restrict without helping the basic metrics goal.

The requested `linadmin` account and temporary password are discussion inputs, not provisioned
changes. If Cockpit is selected, deliver a password hash through a runtime secret file, using the
existing secret-management approach; keep plaintext out of the shared module. Rotate that declared
secret later. With `users.mutableUsers = false`, a manual password change is not durable across
activation, so verify effective host settings before choosing password lifecycle behavior. Journal
membership exposes broad logs, which deserves an explicit scope decision for CI runners.

### Monitoring alternatives and DRY placement

**Glances** is the closest small per-host alternative: a web UI for host metrics, with an existing
`services.glances` module in the pinned nixpkgs. It can run behind a proxy under a URL prefix.
Evaluate its chosen plugins/API permissions and disable actions before describing the deployment as
strictly read-only; it is not a system-journal viewer.
[Glances overview](https://glances.readthedocs.io/en/latest/),
[API and URL prefixes](https://glances.readthedocs.io/en/latest/api/restful.html),
[pinned module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/glances.nix)

**Beszel** better suits a single view of the whole runner fleet: one hub plus agents provide host
metrics/history. It adds a central service and monitoring configuration rather than one login
console per host. The pinned tree already provides `services.beszel.agent` and
`services.beszel.hub`. It does not replace a log viewer. Review account permissions and agent
capabilities for the chosen scope rather than assuming the product name guarantees read-only access.
[Beszel architecture](https://www.beszel.dev/guide/what-is-beszel),
[agent module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/beszel-agent.nix),
[hub module](https://github.com/NixOS/nixpkgs/blob/4975466d324710c576dc11ad614684e6bd8cad8e/nixos/modules/services/monitoring/beszel-hub.nix)

Use three local modules under `nixos/system/config/services/`: `host-observability` (chosen tool and
access policy), `web-analytics` (GoAccess), and `status-page` (static template/timer). Import the
host profile from `nixos/hosts/github-runner/common/default.nix` once for all 20 dedicated runners,
plus the cache and S3 hosts. Other hosts opting into runner services should be checked separately;
JONS currently has a separate runner declaration. Enable web analytics only where an HTTP access log
is useful. Do not replace S3's API root with a landing page; it needs a separate hostname or
explicitly non-conflicting listener.

Recommendation: proceed with the landing-page/live-GoAccess split. Choose Glances for a small
per-host metrics view, or Beszel if fleet-wide history is the priority. Choose Cockpit only if the
accepted requirement is restricted administrative access rather than strict read-only host access.
This remains a design decision; no accounts, firewall openings or services have been deployed.

## Current configuration

[`proxy.nix`](../nixos/hosts/nix-cache/proxy.nix) configures five upstreams from
[`upstreams.json`](../nixos/system/config/services/nix-cache/upstreams.json), sharing
`/var/cache/nginx/nixpkgs`, a `750g` cache target and `100g` minimum filesystem free-space
threshold. The site currently maps its fallback `/` location to that directory and adds
[`browser.css`](../nixos/hosts/nix-cache/browser.css) to autoindex pages. Network allowlists already
restrict access.

The existing custom access log records client address, request, HTTP status, response-body bytes,
cache status and request duration, **but no timestamp**. Reliable historical hourly windows cannot
be reconstructed from those records. Begin the dashboard's history when timestamped logging is
enabled.

The numbered directories are Nginx cache internals: Nginx hashes its cache keys into filenames and
uses the configured directory levels. Its cache manager evicts entries incrementally when size or
free-space limits are crossed; `max_size` is therefore a management target rather than a hard
filesystem quota. With `use_temp_path=off`, temporary cache files also live there.
[Nginx proxy cache documentation](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_path)

## Options

| Option                   | Benefit                                        | Trade-off                       |
| ------------------------ | ---------------------------------------------- | ------------------------------- |
| A. Generated HTML        | Custom storage and cache panels, no JavaScript | Maintain collector and template |
| B. Static shell and JSON | Interactive refresh and time windows           | More browser code               |
| C. Static GoAccess       | Existing traffic and cache charts              | Separate storage summary needed |

GoAccess supports static HTML output, custom CSS, cache-status parsing (`%C`), persisted incremental
processing and bounded date retention. Its real-time mode adds a WebSocket service; static mode does
not need that. Its term “hits” means HTTP requests, so distinguish it from Nginx cache `HIT`.
Disable visitor/host details and strip query strings if evaluating it. Verify supported flags
against the version in this flake. [GoAccess manual](https://goaccess.io/man)

Do not introduce Prometheus/Grafana just for this page. Existing monitoring infrastructure could
supply data later, if there is a separate requirement for alerting or fleet history.

## Recommended data flow

```text
Timestamped cache access log ─┐
Filesystem space/inodes ─────┼─ hourly systemd oneshot ── validated HTML
Service state/events ────────┘          │                     │
                               bounded private history   atomic replacement
                                                             │
                                               Nginx exact root location
```

Use `OnCalendar=hourly` and `Persistent=true`: a missed calendar run can trigger after the timer
returns. A timer does not restart its target while the target is still active. Add a service runtime
limit, low CPU/I/O priority, and a bounded working set. These are safeguards against collection
contending with cache traffic.
[systemd timer documentation source](https://github.com/systemd/systemd/blob/main/man/systemd.timer.xml)

Place generated output under a dedicated directory such as `/var/lib/nix-cache-dashboard/public`;
keep parser state and raw data outside it. Give the collector read access to its inputs and write
access only to its own output/state. Nginx needs read access to published files. The dashboard has
no write actions against the cache.

Generate a temporary HTML file beside the published file, validate it, then replace the published
file with a same-filesystem rename. Keep the last good page if collection fails. Atomic replacement
prevents readers observing half-written HTML.
[Linux rename documentation](https://www.man7.org/linux/man-pages/man2/rename.2.html)

Print the snapshot timestamp, reporting interval and coverage prominently. Display missing values as
unavailable, never zero. Keep the page readable without scripts; an optional tiny age indicator can
mark data older than two expected intervals as stale. An unchanged generated page cannot update its
own freshness warning without browser logic or a later generation, so its absolute timestamp must
always be visible.

Start with hourly generation. If operators need quicker feedback, collect cheap
filesystem/service/log summaries every five minutes later, while keeping expensive directory scans
hourly or daily. A browser refresh cannot make hourly source data fresher.

## Metrics worth showing

All traffic panels cover cache routes only, excluding dashboard assets, status endpoints and
synthetic checks. Show last complete hour and rolling 24 hours; retain seven days of hourly
summaries for small trend charts. Label partial windows while history is building.

| Metric                     | Collection and meaning                                     | Presentation                                                         |
| -------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------- |
| Filesystem available space | Filesystem statistics for the mount containing the cache   | Free GiB and a capacity bar; mark the configured `100g` threshold    |
| Cache directory usage      | Low-priority directory scan measuring allocated bytes      | Usage against the `750g` target; include scan time and “approximate” |
| Inodes available           | Filesystem inode statistics, where meaningful              | Small warning only when running low                                  |
| Cache traffic              | Completed cache-route requests in the interval             | Requests/hour and 24-hour sparkline                                  |
| Cache outcomes             | Counts for each recognized cache status                    | Stacked bar, with strict `HIT` ratio prominently labelled            |
| Bytes delivered            | Sum response-body bytes for completed cache-route requests | GiB/hour; split strict `HIT` traffic from other outcomes             |
| HTTP outcomes              | 2xx/3xx, narinfo 404, archive 404, other 4xx, 5xx          | Small counts, with 5xx emphasized                                    |
| Per-upstream activity      | Group by configured upstream identifier                    | Requests, HIT ratio, bytes, 5xx and last observed successful request |
| Request duration           | Distribution of complete request times by object class     | Optional p50/p95, separating narinfo from large NAR transfers        |
| Collector and Nginx state  | Sampled service state, generation duration, parser errors  | Timestamped state and collection-quality strip                       |

Define strict hit ratio as `HIT / all recognized cache outcomes` for the selected cache-route
window; show numerator and denominator and `N/A` for an empty denominator. Display unknown/missing
outcomes separately. Nginx exposes `MISS`, `BYPASS`, `EXPIRED`, `STALE`, `UPDATING`, `REVALIDATED`
and `HIT`. Keep stale delivery visible because this proxy intentionally serves stale entries during
upstream failures. Revalidated responses contacted the upstream, so do not silently count them as
requests avoided.
[Nginx upstream variables](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#variables)

Label bytes from strict HIT requests **“response bytes served from cache”**, not exact bandwidth
saved. Partial responses, revalidation and retries prevent a simple subtraction from proving
savings. If upstream received bytes are added later, parse their possible multi-attempt values
rather than assuming a scalar.
[Nginx upstream byte variables](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#var_upstream_bytes_received)

Directory size is sampled while files are being added and evicted; it can include temporary files
and filesystem allocation overhead. Filesystem usage also includes non-cache files. Show these as
two separate measures. Do not promise per-upstream disk usage, exact object inventory or eviction
counts from this shared directory. An hourly recursive scan can be expensive for many files; measure
its duration first and lower its frequency if needed.

Narinfo 404s can reflect normal attempts to find unavailable store paths. Report them separately
from archive failures and 5xx; a low hit ratio alone is not a fault. No requests means **idle / no
recent evidence**, not healthy. An hourly local snapshot cannot prove continuous or externally
reachable availability, and a successful cache HIT does not prove the origin is reachable. Keep v1
passive. Optional small HTTP probes can add explicitly labelled sampled reachability later, but also
produce traffic and may warm cache entries.

Open-source `stub_status` optionally supplies active connections and cumulative
accepted/handled/request counters. It does not expose cache occupancy or hit/miss statistics. These
counters are Nginx-wide, not a per-upstream dashboard, and reset across restarts. A localhost-only
endpoint can be sampled if useful; it is unnecessary for the first version.
[Nginx stub status documentation](https://nginx.org/en/docs/http/ngx_http_stub_status_module.html)

## Logging and history

Change the cache access format to JSON lines with `escape=json`. Include timestamp, method, upstream
identifier, object class, status, body bytes, cache outcome and request time. Prefer classifying
requests into `cache-info`, `narinfo` and `nar` over retaining full paths for the dashboard. Quote
optional values so missing values cannot break JSON, and normalize them in the collector. Nginx
supports JSON escaping and `$time_iso8601`/`$msec`; `$request_time` includes receiving the client
request and sending the response, so it is not upstream latency.
[Nginx log module](https://nginx.org/en/docs/http/ngx_http_log_module.html)

Use a single timestamped cache log as the source where practical. Log only the cache routes for
these metrics, or give entries a route classification and explicitly filter the dashboard. Preserve
raw operational logs locally under their existing access controls; do not expose them directly
through the web root.

For modest traffic, the simplest parser reads the current log plus rotated files covering the
reporting window, recomputes that window, then replaces affected hourly buckets. Cap retained
logs/history and account for compressed rotated files. If this is too costly, add inode/offset
checkpointing that handles rotation, truncation, partial final lines and crash recovery. Do not
repeatedly add the entire current log to prior totals. Ensure the configured rotation retention
exceeds the reporting window and handle Nginx reopening logs correctly.

Keep seven days of hourly summaries, a bounded recent-event list (for example 20 entries), and fixed
histogram buckets if calculating latency percentiles. Histograms give approximate percentiles; do
not average hourly percentiles to claim a daily percentile. Report incomplete coverage or dropped
malformed records.

## Events instead of a raw log wall

| Source                | Useful visible event                                                                   | Detail to keep private                                              |
| --------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Cache access log      | Time, upstream label, object class, HTTP/cache status and duration for recent failures | Client IP, full URLs and query strings                              |
| Nginx error log       | Counts of upstream timeouts, connection/TLS failures and cache-write errors            | Raw messages that may contain requests, addresses or internal paths |
| Nginx service journal | Recent start, stop or failed activation events                                         | Unrelated system journal content                                    |
| Dashboard service     | Last completed run, duration, missing input or parse failure                           | Raw stack traces and filesystem paths                               |

Prefer an allowlisted structured event feed: `14:03 · upstream X · nar · HTTP 502 · timeout`. Derive
classifications carefully and label unmatched errors as unclassified rather than guessing. Escape
all rendered text, including log-derived fields; bound line lengths. A dedicated Nginx error log for
this virtual host would simplify attribution; confirm existing destinations before implementing.
Service journal events and per-request Nginx errors are different sources.

## Cyberpunk visual direction

Reuse the existing palette: near-black `#080b14`, cyan `#71f7f0`, magenta `#ff83c1` and amber
`#ffd479`. Use a compact monospace header, restrained glowing panel borders, segmented capacity bars
and inline SVG sparklines. Reserve amber for attention and red for failures; include text/icons so
color is not the sole indicator. Keep body text high-contrast and effects away from data.

```text
 NIX CACHE // SLOPAGEDDON             SNAPSHOT 14:00 AEST
                                     WINDOW 13:00–14:00
 ┌─────────────────┬─────────────────┬─────────────────┐
 │ FREE SPACE      │ CACHE TARGET    │ STRICT HIT RATE │
 │ value + bar     │ usage + bar     │ ratio + counts  │
 ├─────────────────┴─────────────────┴─────────────────┤
 │ TRAFFIC // 24H          CACHE OUTCOMES // 24H         │
 │ requests + bytes       HIT / MISS / STALE / others   │
 ├─────────────────────────────────────────────────────┤
 │ UPSTREAM       REQUESTS    HIT %    BYTES    5XX      │
 │ five compact rows; last observed success / idle      │
 ├─────────────────────────────────────────────────────┤
 │ EVENTS // recent faults and service transitions      │
 └─────────────────────────────────────────────────────┘
```

CSS grid can collapse this into one column on mobile. Use system fonts or locally packaged assets,
native HTML details for expandable event summaries, and pre-rendered charts. Avoid external font/CDN
dependencies, heavy charting libraries, animated counters and flickering text. If adding motion,
respect reduced-motion preferences.

## Serving without disrupting caching

1. Keep all existing regex cache locations, cache keys, upstream paths, TTLs, locks, stale behavior
   and access allowlists intact.
2. Serve the generated page using exact `location = /`. Serve CSS and any script via exact paths
   such as `/_dashboard/style.css`.
3. Replace the old autoindex fallback with an ordinary `location /` returning 404. Do **not** use
   `^~ /`, which would suppress matching cache regex locations. Do not add an application-style
   fallback returning HTML for cache URLs.
   [Nginx location selection](https://nginx.org/en/docs/http/ngx_http_core_module.html#location)
4. Store dashboard files outside the cache directory. Dashboard generation must never require cache
   deletion, cache traversal from HTTP requests, or Nginx restarts.
5. Make HTML revalidate or use a short browser cache lifetime so the displayed timestamp is
   meaningful. Keep dashboard traffic out of cache metrics.

Before deployment, validate generated Nginx configuration and compare cache-info, narinfo and NAR
GET/HEAD behavior for every upstream route. Verify repeated eligible requests still show expected
cache outcomes, unknown paths return 404, access restrictions remain effective, log rotation does
not lose/double-count records, and a failed generator leaves the previous page usable. Test an empty
history and missing inputs as well as the normal case. These checks belong to implementation; none
have been run as part of this design research.

The smallest useful first version is four headline metrics (free space, cache usage, strict hit
ratio and bytes delivered), 24-hour sparklines, five upstream rows, a short sanitized event feed and
clear data freshness. Add faster sampling or deeper analysis only if administrators find an actual
gap.
