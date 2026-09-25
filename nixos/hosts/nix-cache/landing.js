async function loadSummary() {
  const updated = document.getElementById("summary-updated")
  try {
    const response = await fetch("/_dashboard/summary.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Snapshot unavailable")
    const snapshot = await response.json()
    const checked = new Date(snapshot.checked_at)
    if (!Number.isFinite(checked.getTime())) throw new Error("Invalid timestamp")
    const stale = Date.now() - checked.getTime() > 30 * 60 * 1000
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
  }
}

loadSummary()
