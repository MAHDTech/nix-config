;(() => {
  const DEFAULT_INTERVAL_MS = 15 * 60 * 1000
  const DEFAULT_STALE_MS = 30 * 60 * 1000

  function formatBytes(value) {
    if (!Number.isFinite(value)) return "Unavailable"
    const sign = value < 0 ? "−" : ""
    const units = ["B", "KiB", "MiB", "GiB", "TiB"]
    let amount = Math.abs(value)
    let unit = 0
    while (amount >= 1024 && unit < units.length - 1) {
      amount /= 1024
      unit += 1
    }
    return `${sign}${amount.toLocaleString(undefined, { maximumFractionDigits: 1 })} ${units[unit]}`
  }

  function parseCheckedAt(raw, staleMs = DEFAULT_STALE_MS) {
    const date = new Date(raw)
    const time = date.getTime()
    if (!Number.isFinite(time)) {
      return { valid: false, stale: true, date: null }
    }
    return { valid: true, stale: Date.now() - time > staleMs, date }
  }

  function formatStatusText(checked, suffix = "every 15 min") {
    if (!checked.valid) {
      return `Stale · Check time unavailable · ${suffix}`
    }
    return `${checked.stale ? "Stale · " : ""}Updated ${checked.date.toLocaleString()} · ${suffix}`
  }

  function setCapacityMeter(meter, usedBytes, totalBytes, lowSpace = false) {
    const valid = Number.isFinite(usedBytes) && Number.isFinite(totalBytes) && totalBytes > 0
    meter.hidden = !valid
    if (!valid) {
      meter.value = 0
      if (meter.dataset) meter.dataset.state = ""
      return
    }
    const percent = Math.max(0, Math.min(100, (100 * usedBytes) / totalBytes))
    meter.value = percent
    if (meter.dataset) {
      meter.dataset.state = percent >= 90 ? "critical" : lowSpace || percent >= 80 ? "warning" : ""
    }
  }

  function pluralize(count, singular, plural = `${singular}s`) {
    return `${count.toLocaleString()} ${count === 1 ? singular : plural}`
  }

  function startPolling(fn, intervalMs = DEFAULT_INTERVAL_MS) {
    fn()
    return setInterval(fn, intervalMs)
  }

  globalThis.Slopageddon = {
    DEFAULT_INTERVAL_MS,
    DEFAULT_STALE_MS,
    formatBytes,
    parseCheckedAt,
    formatStatusText,
    setCapacityMeter,
    pluralize,
    startPolling,
  }
})()
