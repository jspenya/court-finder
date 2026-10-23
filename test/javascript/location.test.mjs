import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

function controller(name, globals = {}) {
  const source = readFileSync(new URL(`../../app/javascript/controllers/${name}_controller.js`, import.meta.url), "utf8")
    .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
    .replace('export default class', 'globalThis.Subject = class')
  const context = vm.createContext(globals)
  vm.runInContext(source, context)
  return new context.Subject()
}

function results(position = { latitude: 0, longitude: 0 }) {
  const subject = controller("search_results")
  subject.locationElement = { currentPosition: position }
  subject.playTimeValue = "2026-10-24T08:00:00Z"
  return subject
}

function frame(name, latitude, longitude, slot = "2026-10-24T08:00:00Z", status = "available") {
  const label = {}
  return { dataset: { venueName: name, latitude, longitude, earliestSlot: slot, status }, label,
    querySelector: () => label }
}

test("distance sorting overrides slot time and keeps missing coordinates last", () => {
  const subject = results()
  const near = frame("Near", "0", "1", "2026-10-24T10:00:00Z")
  const far = frame("Far", "0", "2")
  const unknown = frame("Unknown", "", "")
  assert.deepEqual([unknown, far, near].sort((a, b) => subject.compareFrames(a, b)), [near, far, unknown])
  assert.ok(Math.abs(subject.geographicDistance(near) - 111.195) < 0.001)
  assert.equal(subject.geographicDistance(frame("Invalid", "NaN", "124")), Infinity)
  assert.equal(subject.geographicDistance(frame("Invalid", "91", "124")), Infinity)
})

test("clearing location restores slot ordering and hides distances", () => {
  const subject = results()
  const near = frame("Near", "0", "1", "2026-10-24T10:00:00Z")
  const far = frame("Far", "0", "2")
  subject.frames = () => [near, far]
  subject.updateDistances()
  assert.equal(near.label.textContent, "111.2 km away · straight line")
  subject.locationElement.currentPosition = undefined
  subject.updateDistances()
  assert.equal(near.label.hidden, true)
  assert.ok(subject.compareFrames(near, far) > 0)
})

test("asynchronous results sort only when loaded and retain errors after available venues", () => {
  const subject = results()
  const near = frame("Near", "0", "1")
  const far = frame("Far", "0", "2")
  const error = frame("Error", "0", "0", "", "error")
  const pending = frame("Pending", "0", "0", "", "pending")
  let frames = [far, error, near, pending]
  const appended = []
  subject.frames = () => frames
  subject.listTarget = { append: f => appended.push(f) }
  subject.venueCountValue = 4
  subject.updateSummary = () => {}
  subject.frameLoaded()
  assert.equal(appended.length, 0)
  pending.dataset.status = "empty"
  subject.frameLoaded()
  assert.deepEqual(appended, [near, far, error, pending])
})

test("Turbo response metadata is copied to the existing frame", () => {
  const subject = results()
  const listeners = {}
  subject.element = { closest: () => null, addEventListener: (name, callback) => listeners[name] = callback }
  subject.frames = () => []
  subject.venueCountValue = 1
  subject.connect()
  const target = frame("Old", "8", "124")
  listeners["turbo:before-frame-render"]({ target, detail: { newFrame: { dataset: { status: "available", venueName: "New", earliestSlot: "time", checkedAt: "10 AM" } } } })
  assert.equal(target.dataset.status, "available")
  assert.equal(target.dataset.earliestSlot, "time")
  assert.equal(target.dataset.latitude, "8")
})

function location({ permission = "prompt", saved, storageBlocked = false } = {}) {
  let success, failure, options, calls = 0
  const storage = new Map(saved ? [["court-finder.location-permission", saved]] : [])
  const subject = controller("location", {
    navigator: {
      permissions: { query: async () => { if (permission === null) throw new Error("Unsupported"); return { state: permission } } },
      geolocation: { getCurrentPosition: (yes, no, opts) => { calls++; success = yes; failure = no; options = opts } }
    },
    localStorage: {
      getItem: key => { if (storageBlocked) throw new Error("Blocked"); return storage.get(key) },
      setItem: (key, value) => { if (storageBlocked) throw new Error("Blocked"); storage.set(key, value) }
    }
  })
  Object.assign(subject, { element: {}, statusTarget: {}, dispatch: () => {} })
  return { subject, storage, calls: () => calls, success: coords => success({ coords }), failure: code => failure({ code }), options: () => options }
}

test("first visit requests native permission and stores only the choice", async () => {
  const request = location()
  await request.subject.connect()
  assert.equal(request.calls(), 1)
  assert.equal(request.options().timeout, 10000)
  request.success({ latitude: 8.4, longitude: 124.6 })
  assert.equal(request.subject.element.currentPosition.latitude, 8.4)
  assert.deepEqual([...request.storage.values()], ["granted"])
})

test("saved denial or dismissal does not prompt again", async () => {
  for (const saved of ["denied", "requested", "granted"]) {
    const request = location({ saved })
    await request.subject.connect()
    assert.equal(request.calls(), 0)
    assert.match(request.subject.statusTarget.textContent, /Location off/)
  }
})

test("browser settings take precedence over the saved choice", async () => {
  const granted = location({ permission: "granted", saved: "denied" })
  await granted.subject.connect()
  assert.equal(granted.calls(), 1)
  const denied = location({ permission: "denied", saved: "granted" })
  await denied.subject.connect()
  assert.equal(denied.calls(), 0)
  assert.equal(denied.storage.get("court-finder.location-permission"), "denied")
})

test("denial and timeout leave availability search usable", async () => {
  for (const code of [1, 3]) {
    const request = location()
    await request.subject.connect()
    request.failure(code)
    assert.equal(request.subject.element.currentPosition, undefined)
    assert.match(request.subject.statusTarget.textContent, /all venues/)
    assert.equal(request.storage.get("court-finder.location-permission"), code === 1 ? "denied" : "requested")
  }
})

test("disconnect ignores late permission queries and position callbacks", async () => {
  const pending = location()
  const connecting = pending.subject.connect()
  pending.subject.disconnect()
  await connecting
  assert.equal(pending.calls(), 0)
  const request = location()
  await request.subject.connect()
  request.subject.disconnect()
  request.success({ latitude: 8, longitude: 124 })
  assert.equal(request.subject.element.currentPosition, undefined)
})

test("unsupported permission queries use the remembered choice", async () => {
  for (const saved of [undefined, "granted", "denied", "requested"]) {
    const request = location({ permission: null, saved })
    await request.subject.connect()
    assert.equal(request.calls(), !saved || saved === "granted" ? 1 : 0)
  }
})

test("blocked storage remembers dismissal for the current session", async () => {
  const request = location({ storageBlocked: true })
  await request.subject.connect()
  request.failure(1)
  request.subject.disconnect()
  await request.subject.connect()
  assert.equal(request.calls(), 1)
})

test("unsupported geolocation explains fallback", async () => {
  const subject = controller("location", { navigator: {} })
  Object.assign(subject, { element: {}, statusTarget: {}, dispatch: () => {} })
  await subject.connect()
  assert.match(subject.statusTarget.textContent, /showing all venues/)
})
