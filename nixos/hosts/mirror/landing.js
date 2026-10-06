function formatBytes(value) {
  if (!Number.isFinite(value)) return "Unavailable"
  const units = ["B", "KiB", "MiB", "GiB", "TiB"]
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${value.toLocaleString(undefined, { maximumFractionDigits: 1 })} ${units[unit]}`
}

async function loadSummary() {
  const status = document.getElementById("statistics-updated")
  try {
    const response = await fetch("/_dashboard/summary.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Summary unavailable")
    const snapshot = await response.json()
    const storage = snapshot.storage
    const checked = new Date(snapshot.checked_at)
    const stale =
      !Number.isFinite(checked.getTime()) || Date.now() - checked.getTime() > 30 * 60 * 1000
    status.textContent = `${stale ? "Snapshot stale. " : ""}Last checked ${checked.toLocaleString()}. Updated every 15 minutes.`
    document.getElementById("disk-free").textContent = formatBytes(storage.available_bytes)
    document.getElementById("disk-total").textContent = formatBytes(storage.total_bytes)
    document.getElementById("mirror-size").textContent = formatBytes(storage.content_bytes)
    document.getElementById("disk-detail").textContent =
      `${formatBytes(storage.used_bytes)} used. Shared filesystem with NixOS.`
    const meter = document.getElementById("disk-meter")
    meter.hidden = !(storage.total_bytes > 0)
    meter.value = (100 * storage.used_bytes) / storage.total_bytes
  } catch {
    status.textContent =
      "Disk statistics unavailable. Any displayed values are from the last successful load."
  }
}

loadSummary()
setInterval(loadSummary, 15 * 60 * 1000)
