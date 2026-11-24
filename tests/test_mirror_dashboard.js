// Exercise mirror dashboard states including zero capacity, null storage and invalid timestamps.
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const elements = new Map()
const element = (id) => {
  if (!elements.has(id)) elements.set(id, { textContent: "", dataset: {}, hidden: true, value: 0 })
  return elements.get(id)
}

let snapshot = {
  checked_at: new Date().toISOString(),
  storage: {
    available_bytes: 400 * 1024 ** 3,
    total_bytes: 1000 * 1024 ** 3,
    used_bytes: 600 * 1024 ** 3,
    content_bytes: 250 * 1024 ** 3,
  },
}
let fail = false

const context = vm.createContext({
  document: { getElementById: element },
  fetch: async () => ({ ok: !fail, json: async () => snapshot }),
  setInterval: (_callback, interval) => assert.equal(interval, 15 * 60 * 1000),
})
vm.runInContext(
  fs.readFileSync(
    path.join(__dirname, "../nixos/system/config/services/slopageddon-web/common.js"),
    "utf8"
  ),
  context
)
vm.runInContext(
  fs.readFileSync(path.join(__dirname, "../nixos/hosts/mirror/landing.js"), "utf8"),
  context
)

async function main() {
  await context.loadSummary()
  assert.equal(element("disk-free").textContent, "400 GiB")
  assert.equal(element("disk-total").textContent, "1,000 GiB")
  assert.equal(element("mirror-size").textContent, "250 GiB")
  assert.equal(element("disk-meter").hidden, false)
  assert.equal(element("disk-meter").value, 60)
  assert.equal(element("statistics-updated").dataset.state, "")

  // Zero capacity must hide meter cleanly without NaN or Infinity.
  snapshot = {
    checked_at: "not-a-date",
    storage: { available_bytes: 0, total_bytes: 0, used_bytes: 0, content_bytes: null },
  }
  await context.loadSummary()
  assert.equal(element("disk-meter").hidden, true)
  assert.equal(element("disk-meter").value, 0)
  assert.equal(element("mirror-size").textContent, "Unavailable")
  assert.match(element("statistics-updated").textContent, /^Stale · /)
  assert.doesNotMatch(element("statistics-updated").textContent, /Invalid Date/)
  assert.equal(element("statistics-updated").dataset.state, "warning")

  // Null storage must not crash.
  snapshot = { checked_at: new Date().toISOString(), storage: null }
  await context.loadSummary()
  assert.equal(element("disk-free").textContent, "Unavailable")
  assert.equal(element("disk-meter").hidden, true)
  assert.match(element("disk-detail").textContent, /unavailable/i)

  fail = true
  await context.loadSummary()
  assert.match(element("statistics-updated").textContent, /Couldn't refresh statistics/)
  assert.equal(element("statistics-updated").dataset.state, "warning")

  console.log(
    "PASS: mirror dashboard metrics, zero capacity, null storage, invalid date and errors"
  )
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
