let hasLoaded = false

async function loadSummary() {
  const { formatBytes, parseCheckedAt, formatStatusText, setCapacityMeter } = globalThis.Slopageddon
  const status = document.getElementById("statistics-updated")
  try {
    const response = await fetch("/_dashboard/summary.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Summary unavailable")
    const snapshot = await response.json()
    const storage = snapshot.storage
    const checked = parseCheckedAt(snapshot.checked_at)
    status.textContent = formatStatusText(checked)
    if (status.dataset) status.dataset.state = checked.stale ? "warning" : ""

    document.getElementById("disk-free").textContent = formatBytes(storage?.available_bytes)
    document.getElementById("disk-total").textContent = formatBytes(storage?.total_bytes)
    document.getElementById("mirror-size").textContent = formatBytes(storage?.content_bytes)
    document.getElementById("disk-detail").textContent = storage
      ? `${formatBytes(storage.used_bytes)} used. Shared filesystem with NixOS.`
      : "Disk measurement unavailable."

    setCapacityMeter(
      document.getElementById("disk-meter"),
      storage?.used_bytes,
      storage?.total_bytes
    )
    hasLoaded = true
  } catch {
    status.textContent = hasLoaded
      ? "Couldn't refresh statistics. Showing last snapshot."
      : "Disk statistics unavailable. Refreshes every 15 minutes."
    if (status.dataset) status.dataset.state = "warning"
  }
}

globalThis.Slopageddon.startPolling(loadSummary)
