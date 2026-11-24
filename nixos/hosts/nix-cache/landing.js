let hasLoaded = false

function renderStatistics(snapshot, checked) {
  const { formatBytes, formatStatusText, setCapacityMeter } = globalThis.Slopageddon
  const element = (id) => document.getElementById(id)
  const storage = snapshot.storage
  const traffic = snapshot.traffic
  const updated = element("statistics-updated")
  updated.textContent = formatStatusText(checked)
  updated.dataset.state = checked.stale ? "warning" : ""

  element("disk-free").textContent = formatBytes(storage?.available_bytes)
  const lowSpace = Boolean(storage && storage.available_bytes < storage.reserve_bytes)
  element("disk-free").dataset.state = lowSpace ? "warning" : ""
  element("disk-detail").textContent = storage
    ? `${formatBytes(storage.total_bytes)} total · ${formatBytes(storage.reserve_bytes)} free-space reserve.${lowSpace ? " Below reserve; cache eviction may be active." : ""}`
    : "Disk measurement unavailable."

  setCapacityMeter(element("disk-meter"), storage?.used_bytes, storage?.total_bytes, lowSpace)

  element("cache-size").textContent = formatBytes(storage?.cache_bytes)
  element("cache-detail").textContent = storage
    ? `${formatBytes(storage.limit_bytes)} cache limit. Shared disk with NixOS.`
    : "Cache size measurement unavailable."

  const change = storage?.change_bytes
  const previousChecked = storage?.previous_checked_at
    ? new Date(storage.previous_checked_at)
    : null
  element("cache-growth").textContent =
    Number.isFinite(change) && previousChecked && Number.isFinite(previousChecked.getTime())
      ? `Cache size change: ${change >= 0 ? "+" : ""}${formatBytes(change)} since ${previousChecked.toLocaleString()}. Includes additions and evictions.`
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
  const { parseCheckedAt, formatStatusText } = globalThis.Slopageddon
  const updated = document.getElementById("summary-updated")
  const statistics = document.getElementById("statistics-updated")
  try {
    const response = await fetch("/_dashboard/summary.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Snapshot unavailable")
    const snapshot = await response.json()
    const checked = parseCheckedAt(snapshot.checked_at)
    if (!checked.valid) throw new Error("Invalid timestamp")
    renderStatistics(snapshot, checked)
    for (const row of document.querySelectorAll("[data-endpoint]")) {
      const endpoint = (snapshot.endpoints || []).find((item) => item.name === row.dataset.endpoint)
      if (!endpoint) continue
      const status = row.querySelector(".endpoint-status")
      status.textContent = checked.stale
        ? "Stale"
        : {
            reachable: "Metadata reachable",
            unavailable: "Unavailable",
            invalid: "Invalid metadata",
          }[endpoint.status] || "Unknown"
      status.dataset.state = checked.stale ? "stale" : endpoint.status
      row.querySelector(".endpoint-metrics").textContent =
        endpoint.status === "reachable"
          ? `${endpoint.duration_ms} ms · Priority ${endpoint.priority ?? "not advertised"}`
          : "—"
    }
    updated.textContent = formatStatusText(checked)
    updated.dataset.state = checked.stale ? "warning" : ""
    hasLoaded = true
  } catch {
    updated.textContent = hasLoaded
      ? "Couldn't refresh upstream status. Showing last snapshot."
      : "Upstream status unavailable. Refreshes every 15 minutes."
    updated.dataset.state = "warning"
    statistics.textContent = hasLoaded
      ? "Couldn't refresh statistics. Showing last snapshot."
      : "Statistics unavailable. Refreshes every 15 minutes."
    statistics.dataset.state = "warning"
  }
}

globalThis.Slopageddon.startPolling(loadSummary)
