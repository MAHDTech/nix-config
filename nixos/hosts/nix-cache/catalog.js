const pageSize = 100
let entries = []
let page = 0

function formatSize(value) {
  const units = ["B", "KiB", "MiB", "GiB"]
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${value.toLocaleString(undefined, { maximumFractionDigits: 1 })} ${units[unit]}`
}

function renderCatalog() {
  const search = document.getElementById("catalog-search").value.toLowerCase()
  const upstream = document.getElementById("catalog-upstream").value
  const kind = document.getElementById("catalog-kind").value
  const filtered = entries.filter(
    (entry) =>
      (!upstream || entry.upstream === upstream) &&
      (!kind || entry.kind === kind) &&
      `${entry.name} ${entry.url}`.toLowerCase().includes(search)
  )
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  page = Math.min(page, pages - 1)
  const rows = document.getElementById("catalog-rows")
  rows.replaceChildren()
  for (const entry of filtered.slice(page * pageSize, (page + 1) * pageSize)) {
    const row = document.createElement("tr")
    const name = document.createElement("td")
    const link = document.createElement("a")
    link.href = entry.url
    link.textContent = entry.name
    name.append(link)
    row.append(name)
    for (const value of [entry.upstream, formatSize(entry.size_bytes), entry.kind]) {
      const cell = document.createElement("td")
      cell.textContent = value
      row.append(cell)
    }
    rows.append(row)
  }
  if (filtered.length === 0) {
    const row = document.createElement("tr")
    const cell = document.createElement("td")
    cell.colSpan = 4
    cell.textContent = "No cached downloads match these filters."
    row.append(cell)
    rows.append(row)
  }
  document.getElementById("catalog-page").textContent =
    `${filtered.length.toLocaleString()} files · Page ${page + 1} of ${pages}`
  document.getElementById("catalog-previous").disabled = page === 0
  document.getElementById("catalog-next").disabled = page + 1 >= pages
}

async function loadCatalog() {
  const status = document.getElementById("catalog-status")
  try {
    const response = await fetch("/_dashboard/catalog.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Catalog unavailable")
    const snapshot = await response.json()
    entries = snapshot.entries.filter(
      (entry) =>
        typeof entry.name === "string" &&
        typeof entry.upstream === "string" &&
        Number.isFinite(entry.size_bytes) &&
        entry.size_bytes >= 0 &&
        /^(?:\/(?:[a-z0-9-]+))?\/(?:[0-9a-z]{32}\.narinfo|nar\/[A-Za-z0-9._-]+)$/.test(entry.url) &&
        ["archive", "metadata"].includes(entry.kind)
    )
    const select = document.getElementById("catalog-upstream")
    const selected = select.value
    select.replaceChildren(new Option("All upstreams", ""))
    for (const upstream of [...new Set(entries.map((entry) => entry.upstream))].sort()) {
      select.append(new Option(upstream, upstream))
    }
    select.value = selected
    const checked = new Date(snapshot.checked_at)
    const stale =
      !Number.isFinite(checked.getTime()) || Date.now() - checked.getTime() > 30 * 60 * 1000
    status.textContent = `${stale ? "Snapshot stale. " : ""}Last checked ${checked.toLocaleString()}. Updated every 15 minutes.${snapshot.truncated ? " Partial catalog: scan limit reached." : ""}`
    renderCatalog()
  } catch {
    status.textContent =
      "Catalog unavailable. Any displayed entries are from the last successful load."
  }
}

for (const id of ["catalog-search", "catalog-upstream", "catalog-kind"]) {
  document.getElementById(id).addEventListener("input", () => {
    page = 0
    renderCatalog()
  })
}
document.getElementById("catalog-previous").addEventListener("click", () => {
  page -= 1
  renderCatalog()
})
document.getElementById("catalog-next").addEventListener("click", () => {
  page += 1
  renderCatalog()
})
loadCatalog()
setInterval(loadCatalog, 15 * 60 * 1000)
