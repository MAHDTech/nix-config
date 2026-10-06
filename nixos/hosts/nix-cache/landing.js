function formatBytes(value) {
  if (!Number.isFinite(value)) return "Unavailable"
  const units = ["B", "KiB", "MiB", "GiB", "TiB"]
  const exponent = value > 0 ? Math.min(Math.floor(Math.log(value) / Math.log(1024)), 4) : 0
  return `${(value / 1024 ** exponent).toLocaleString(undefined, { maximumFractionDigits: 1 })} ${units[exponent]}`
}

function renderStatistics(snapshot, stale, checked) {
  const element = (id) => document.getElementById(id)
  const storage = snapshot.storage
  const traffic = snapshot.traffic
  const updated = element("statistics-updated")
  updated.textContent = `${stale ? "Snapshot stale. " : ""}Last checked ${checked.toLocaleString()}. Updated every 15 minutes.`
  updated.dataset.state = stale ? "warning" : ""
  element("disk-free").textContent = formatBytes(storage?.available_bytes)
  const lowSpace = storage && storage.available_bytes < storage.reserve_bytes
  element("disk-free").dataset.state = lowSpace ? "warning" : ""
  element("disk-detail").textContent = storage
    ? `${formatBytes(storage.total_bytes)} total · ${formatBytes(storage.reserve_bytes)} free-space reserve.${lowSpace ? " Below reserve; cache eviction may be active." : ""}`
    : "Disk measurement unavailable."
  const meter = element("disk-meter")
  meter.hidden = !storage
  if (storage) meter.value = (100 * storage.used_bytes) / storage.total_bytes
  element("cache-size").textContent = formatBytes(storage?.cache_bytes)
  element("cache-detail").textContent = storage
    ? `${formatBytes(storage.limit_bytes)} cache limit. Shared disk with NixOS.`
    : "Cache size measurement unavailable."
  const change = storage?.change_bytes
  element("cache-growth").textContent = Number.isFinite(change)
    ? `Cache size change: ${change >= 0 ? "+" : "−"}${formatBytes(Math.abs(change))} since ${new Date(storage.previous_checked_at).toLocaleString()}. Includes additions and evictions.`
    : "Cache growth appears after two successful size measurements."
  element("cache-hit-rate").textContent = traffic
    ? traffic.archive_bytes > 0
      ? `${((100 * traffic.hit_bytes) / traffic.archive_bytes).toFixed(1)}%`
      : "No traffic"
    : "Unavailable"
  element("hit-detail").textContent = traffic
    ? `${formatBytes(traffic.hit_bytes)} served from disk in the last 24 hours. Hit rate is measured by archive bytes.`
    : "Traffic statistics unavailable."
  element("archive-bytes").textContent = formatBytes(traffic?.archive_bytes)
  element("cache-requests").textContent = traffic
    ? traffic.requests.toLocaleString()
    : "Unavailable"
  element("requests-detail").textContent = traffic
    ? `${traffic.not_found.toLocaleString()} not-found responses in the last 24 hours. Normal when probing for packages.`
    : "Traffic statistics unavailable."
  element("cache-errors").textContent = traffic ? traffic.errors.toLocaleString() : "Unavailable"
  element("cache-errors").dataset.state = traffic?.errors > 0 ? "warning" : ""
  element("errors-detail").textContent =
    traffic?.requests > 0
      ? `${((100 * traffic.errors) / traffic.requests).toFixed(2)}% of requests returned HTTP 5xx in the last 24 hours.`
      : "HTTP 5xx responses over the last 24 hours."
}

async function loadSummary() {
  const updated = document.getElementById("summary-updated")
  try {
    const response = await fetch("/_dashboard/summary.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Snapshot unavailable")
    const snapshot = await response.json()
    const checked = new Date(snapshot.checked_at)
    if (!Number.isFinite(checked.getTime())) throw new Error("Invalid timestamp")
    const stale = Date.now() - checked.getTime() > 30 * 60 * 1000
    renderStatistics(snapshot, stale, checked)
    for (const row of document.querySelectorAll("[data-endpoint]")) {
      const endpoint = snapshot.endpoints.find((item) => item.name === row.dataset.endpoint)
      if (!endpoint) continue
      const status = row.querySelector(".endpoint-status")
      status.textContent = stale
        ? "Stale"
        : {
            reachable: "Metadata reachable",
            unavailable: "Unavailable",
            invalid: "Invalid metadata",
          }[endpoint.status] || "Unknown"
      status.dataset.state = stale ? "stale" : endpoint.status
      row.querySelector(".endpoint-metrics").textContent =
        endpoint.status === "reachable"
          ? `${endpoint.duration_ms} ms · Priority ${endpoint.priority ?? "not advertised"}`
          : "—"
    }
    updated.textContent = `${stale ? "Snapshot stale. " : ""}Last checked ${checked.toLocaleString()}. Updated every 15 minutes.`
  } catch {
    updated.textContent = "Summary unavailable. Checks run every 15 minutes; refresh to try again."
    const statistics = document.getElementById("statistics-updated")
    statistics.textContent =
      "Could not refresh statistics. Any figures shown are from the previous snapshot."
    statistics.dataset.state = "warning"
  }
}

loadSummary()
setInterval(loadSummary, 15 * 60 * 1000)
