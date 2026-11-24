const pageSize = 100
let entries = []
let page = 0
let hasLoaded = false
let searchTimer = null

const kindLabels = {
  archive: "Archive",
  metadata: "Metadata",
}

function readFiltersFromUrl() {
  if (typeof globalThis.location === "undefined" || !globalThis.location.search) return
  const params = new URLSearchParams(globalThis.location.search)
  const q = params.get("q")
  const upstream = params.get("upstream")
  const kind = params.get("kind")
  const rawPage = Number.parseInt(params.get("page") || "", 10)
  if (q !== null) document.getElementById("catalog-search").value = q
  if (upstream !== null) document.getElementById("catalog-upstream").value = upstream
  if (kind !== null && ["", "archive", "metadata"].includes(kind)) {
    document.getElementById("catalog-kind").value = kind
  }
  if (Number.isInteger(rawPage) && rawPage >= 1) page = rawPage - 1
}

function syncFiltersToUrl() {
  if (
    typeof globalThis.location === "undefined" ||
    typeof globalThis.history === "undefined" ||
    typeof globalThis.history.replaceState !== "function"
  ) {
    return
  }
  const params = new URLSearchParams()
  const search = document.getElementById("catalog-search").value.trim()
  const upstream = document.getElementById("catalog-upstream").value
  const kind = document.getElementById("catalog-kind").value
  if (search) params.set("q", search)
  if (upstream) params.set("upstream", upstream)
  if (kind !== "archive") params.set("kind", kind)
  if (page > 0) params.set("page", String(page + 1))
  const query = params.toString()
  const next = `${globalThis.location.pathname}${query ? `?${query}` : ""}`
  globalThis.history.replaceState(null, "", next)
}

function renderCatalog() {
  const { formatBytes, pluralize } = globalThis.Slopageddon
  const search = document.getElementById("catalog-search").value.trim().toLowerCase()
  const upstream = document.getElementById("catalog-upstream").value
  const kind = document.getElementById("catalog-kind").value
  const filtered = entries.filter(
    (entry) =>
      (!upstream || entry.upstream === upstream) &&
      (!kind || entry.kind === kind) &&
      (!search || entry._search.includes(search))
  )
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  page = Math.max(0, Math.min(page, pages - 1))
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

    const upstreamCell = document.createElement("td")
    upstreamCell.textContent = entry.upstream
    row.append(upstreamCell)

    const sizeCell = document.createElement("td")
    sizeCell.textContent = formatBytes(entry.size_bytes)
    row.append(sizeCell)

    const kindCell = document.createElement("td")
    const badge = document.createElement("span")
    badge.className = `badge badge--${entry.kind}`
    badge.textContent = kindLabels[entry.kind] || entry.kind
    kindCell.append(badge)
    row.append(kindCell)

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
    `${pluralize(filtered.length, "file")} · Page ${page + 1} of ${pages}`
  document.getElementById("catalog-previous").disabled = page === 0
  document.getElementById("catalog-next").disabled = page + 1 >= pages
  syncFiltersToUrl()
}

async function loadCatalog() {
  const { parseCheckedAt, formatStatusText } = globalThis.Slopageddon
  const status = document.getElementById("catalog-status")
  try {
    const response = await fetch("/_dashboard/catalog.json", { cache: "no-store" })
    if (!response.ok) throw new Error("Catalog unavailable")
    const snapshot = await response.json()
    entries = (snapshot.entries || [])
      .filter(
        (entry) =>
          typeof entry.name === "string" &&
          typeof entry.upstream === "string" &&
          Number.isFinite(entry.size_bytes) &&
          entry.size_bytes >= 0 &&
          /^(?:\/(?:[a-z0-9-]+))?\/(?:[0-9a-z]{32}\.narinfo|nar\/[A-Za-z0-9._-]+)$/.test(
            entry.url
          ) &&
          ["archive", "metadata"].includes(entry.kind)
      )
      .map((entry) => ({
        ...entry,
        _search: `${entry.name} ${entry.url}`.toLowerCase(),
      }))

    const select = document.getElementById("catalog-upstream")
    const selected = select.value
    select.replaceChildren(new Option("All upstreams", ""))
    for (const upstream of [...new Set(entries.map((entry) => entry.upstream))].sort()) {
      select.append(new Option(upstream, upstream))
    }
    select.value = selected

    const checked = parseCheckedAt(snapshot.checked_at)
    status.textContent = `${formatStatusText(checked)}${snapshot.truncated ? " · Partial catalog: scan limit reached." : ""}`
    if (status.dataset) {
      status.dataset.state = checked.stale || snapshot.truncated ? "warning" : ""
    }
    hasLoaded = true
    renderCatalog()
  } catch {
    status.textContent = hasLoaded
      ? "Couldn't refresh catalog. Showing last snapshot."
      : "Catalog unavailable. Refreshes every 15 minutes."
    if (status.dataset) status.dataset.state = "warning"
  }
}

readFiltersFromUrl()
document.getElementById("catalog-search").addEventListener("input", () => {
  page = 0
  if (typeof setTimeout === "function") {
    clearTimeout(searchTimer)
    searchTimer = setTimeout(renderCatalog, 150)
  } else {
    renderCatalog()
  }
})
for (const id of ["catalog-upstream", "catalog-kind"]) {
  document.getElementById(id).addEventListener("input", () => {
    page = 0
    renderCatalog()
  })
}
document.getElementById("catalog-previous").addEventListener("click", () => {
  page = Math.max(0, page - 1)
  renderCatalog()
})
document.getElementById("catalog-next").addEventListener("click", () => {
  page += 1
  renderCatalog()
})
globalThis.Slopageddon.startPolling(loadCatalog)
