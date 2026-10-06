// Exercise filtering, pagination and safe rendering without a browser dependency.
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

class Element {
  constructor() {
    this.children = []
    this.listeners = {}
    this.value = ""
    this.textContent = ""
  }
  append(...children) {
    this.children.push(...children)
  }
  replaceChildren(...children) {
    this.children = children
  }
  addEventListener(event, callback) {
    this.listeners[event] = callback
  }
}
const elements = new Map()
function element(id) {
  if (!elements.has(id)) elements.set(id, new Element())
  return elements.get(id)
}
element("catalog-kind").value = "archive"
const entries = Array.from({ length: 105 }, (_, i) => ({
  name: i === 0 ? "<img src=x>" : `package-${i}`,
  upstream: "nixpkgs",
  url: `/nar/${i}.nar.xz`,
  size_bytes: 1024,
  kind: "archive",
}))
entries.push({
  name: "other",
  upstream: "devenv",
  url: "/devenv/nar/other.nar.zst",
  size_bytes: 200,
  kind: "archive",
})
entries.push({
  name: "metadata",
  upstream: "nixpkgs",
  url: "/" + "a".repeat(32) + ".narinfo",
  size_bytes: 100,
  kind: "metadata",
})
entries.push({
  name: "unsafe",
  upstream: "nixpkgs",
  url: "//evil.example/",
  size_bytes: 1,
  kind: "archive",
})
let fail = false
const snapshot = { checked_at: new Date().toISOString(), entries, truncated: false }
const context = vm.createContext({
  document: { getElementById: element, createElement: () => new Element() },
  Option: class extends Element {
    constructor(text, value) {
      super()
      this.textContent = text
      this.value = value
    }
  },
  fetch: async () => ({ ok: !fail, json: async () => snapshot }),
  setInterval: (_, interval) => assert.equal(interval, 15 * 60 * 1000),
})
vm.runInContext(
  fs.readFileSync(path.join(__dirname, "../nixos/hosts/nix-cache/catalog.js"), "utf8"),
  context
)

async function main() {
  await context.loadCatalog()
  assert.equal(element("catalog-rows").children.length, 100)
  assert.equal(
    element("catalog-rows").children[0].children[0].children[0].textContent,
    "<img src=x>"
  )
  assert.match(element("catalog-page").textContent, /106 files.*Page 1 of 2/)
  element("catalog-next").listeners.click()
  assert.equal(element("catalog-rows").children.length, 6)
  assert.equal(element("catalog-next").disabled, true)
  element("catalog-search").value = "package-104"
  element("catalog-search").listeners.input()
  assert.equal(element("catalog-rows").children.length, 1)
  assert.match(element("catalog-page").textContent, /1 files.*Page 1 of 1/)
  element("catalog-search").value = ""
  element("catalog-upstream").value = "devenv"
  element("catalog-upstream").listeners.input()
  assert.equal(
    element("catalog-rows").children[0].children[0].children[0].href,
    "/devenv/nar/other.nar.zst"
  )
  element("catalog-upstream").value = ""
  element("catalog-kind").value = "metadata"
  element("catalog-kind").listeners.input()
  assert.equal(element("catalog-rows").children.length, 1)
  snapshot.checked_at = "2020-01-01T00:00:00Z"
  snapshot.truncated = true
  await context.loadCatalog()
  assert.match(element("catalog-status").textContent, /Snapshot stale/)
  assert.match(element("catalog-status").textContent, /Partial catalog/)
  fail = true
  await context.loadCatalog()
  assert.match(element("catalog-status").textContent, /Catalog unavailable/)
  assert.equal(element("catalog-rows").children.length, 1)
  console.log(
    "PASS: safe catalog rendering, URL validation, pagination, filters, stale and failed snapshots"
  )
}
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
