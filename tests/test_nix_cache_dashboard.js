// Exercise dashboard states without requiring a browser or external packages.
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const elements = new Map()
const element = (id) => {
  if (!elements.has(id)) elements.set(id, { textContent: "", dataset: {} })
  return elements.get(id)
}
const snapshot = {
  checked_at: new Date().toISOString(),
  endpoints: [],
  storage: {
    available_bytes: 200 * 1024 ** 3,
    total_bytes: 1000 * 1024 ** 3,
    used_bytes: 750 * 1024 ** 3,
    reserve_bytes: 100 * 1024 ** 3,
    cache_bytes: 500 * 1024 ** 3,
    limit_bytes: 750 * 1024 ** 3,
    change_bytes: null,
  },
  traffic: { requests: 10, errors: 1, not_found: 4, archive_bytes: 500, hit_bytes: 400 },
}
let fail = false
const context = vm.createContext({
  document: { getElementById: element, querySelectorAll: () => [] },
  fetch: async () => ({ ok: !fail, json: async () => snapshot }),
  setInterval: (callback, interval) => assert.equal(interval, 15 * 60 * 1000),
})
vm.runInContext(
  fs.readFileSync(path.join(__dirname, "../nixos/hosts/nix-cache/landing.js"), "utf8"),
  context
)

async function main() {
  await context.loadSummary()
  assert.equal(element("disk-free").textContent, "200 GiB")
  assert.equal(element("disk-meter").value, 75)
  assert.equal(element("cache-hit-rate").textContent, "80.0%")
  assert.equal(element("cache-errors").textContent, "1")
  assert.match(element("requests-detail").textContent, /4 not-found/)
  assert.match(element("cache-growth").textContent, /two successful/)

  snapshot.storage.available_bytes = 99 * 1024 ** 3
  snapshot.storage.change_bytes = -1024
  snapshot.storage.previous_checked_at = new Date().toISOString()
  await context.loadSummary()
  assert.equal(element("disk-free").dataset.state, "warning")
  assert.match(element("disk-detail").textContent, /Below reserve/)
  assert.match(element("cache-growth").textContent, /−1 KiB/)

  snapshot.traffic.archive_bytes = 0
  snapshot.traffic.hit_bytes = 0
  snapshot.checked_at = "2020-01-01T00:00:00Z"
  await context.loadSummary()
  assert.equal(element("cache-hit-rate").textContent, "No traffic")
  assert.match(element("statistics-updated").textContent, /Snapshot stale/)

  snapshot.storage = null
  snapshot.traffic = null
  await context.loadSummary()
  assert.equal(element("disk-free").textContent, "Unavailable")
  assert.equal(element("cache-hit-rate").textContent, "Unavailable")
  assert.equal(element("disk-meter").hidden, true)

  fail = true
  await context.loadSummary()
  assert.match(element("statistics-updated").textContent, /Could not refresh/)
  assert.equal(element("statistics-updated").dataset.state, "warning")
  console.log(
    "PASS: dashboard metrics, empty traffic, low disk, eviction, stale and failed snapshots"
  )
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
