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

function location() {
  let success, failure, options
  const subject = controller("location", { navigator: { geolocation: { getCurrentPosition: (yes, no, opts) => { success = yes; failure = no; options = opts } } } })
  Object.assign(subject, { element: {}, buttonTarget: {}, statusTarget: {}, clearTarget: {}, dispatch: () => {} })
  return { subject, success: coords => success({ coords }), failure: code => failure({ code }), options: () => options }
}

test("location is requested only on click and clearing ignores late callbacks", () => {
  const request = location()
  assert.equal(request.options(), undefined)
  request.subject.locate()
  assert.equal(request.subject.buttonTarget.disabled, true)
  assert.equal(request.options().timeout, 10000)
  request.success({ latitude: 8.4, longitude: 124.6 })
  assert.equal(request.subject.element.currentPosition.latitude, 8.4)
  assert.equal(request.subject.clearTarget.hidden, false)
  request.subject.clear()
  request.success({ latitude: 10, longitude: 100 })
  assert.equal(request.subject.element.currentPosition, undefined)
})

test("denied permission and timeouts leave search available and allow retry", () => {
  const request = location()
  request.subject.locate()
  request.failure(1)
  assert.match(request.subject.statusTarget.textContent, /permission was denied/)
  assert.equal(request.subject.buttonTarget.disabled, false)
  request.subject.locate()
  request.failure(3)
  assert.match(request.subject.statusTarget.textContent, /Try again/)
  assert.equal(request.subject.element.currentPosition, undefined)
})

test("unsupported geolocation explains fallback", () => {
  const subject = controller("location", { navigator: {} })
  subject.statusTarget = {}
  subject.locate()
  assert.match(subject.statusTarget.textContent, /still check all venues/)
})
