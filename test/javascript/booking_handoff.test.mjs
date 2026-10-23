import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

function setup() {
  const calls = []
  const source = readFileSync(new URL("../../app/javascript/controllers/booking_handoff_controller.js", import.meta.url), "utf8")
    .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
    .replace('export default class', 'globalThis.Subject = class')
  const context = vm.createContext({ window: { open: (...args) => calls.push(args) } })
  vm.runInContext(source, context)
  const subject = new context.Subject()
  subject.linkTarget = { href: "https://example.com/booking", focus: () => calls.push("focus") }
  subject.dialogTarget = {
    open: false,
    showModal() { this.open = true },
    close() { this.open = false },
    getBoundingClientRect: () => ({ left: 20, right: 300, top: 20, bottom: 400 })
  }
  return { subject, calls }
}

test("booking link shows the disclaimer without navigating; acknowledgement opens the venue", () => {
  const { subject, calls } = setup()
  let prevented = false
  subject.open({ preventDefault: () => { prevented = true } })
  assert.equal(prevented, true)
  assert.equal(subject.dialogTarget.open, true)
  assert.deepEqual(calls, [])
  subject.continue()
  assert.deepEqual(calls, [["https://example.com/booking", "_blank", "noopener,noreferrer"]])
  assert.equal(subject.dialogTarget.open, false)
})

test("backdrop dismissal never opens the venue and restores focus", () => {
  const { subject, calls } = setup()
  subject.dialogTarget.open = true
  subject.dismissBackdrop({ target: subject.dialogTarget, clientX: 50, clientY: 50 })
  assert.equal(subject.dialogTarget.open, true, "clicking modal padding must not dismiss")
  subject.dismissBackdrop({ target: subject.dialogTarget, clientX: 10, clientY: 50 })
  assert.equal(subject.dialogTarget.open, false)
  assert.deepEqual(calls, [])
  subject.restoreFocus()
  assert.deepEqual(calls, ["focus"])
})

test("removing a result closes its open dialog without navigating", () => {
  const { subject, calls } = setup()
  subject.dialogTarget.open = true
  subject.disconnect()
  assert.equal(subject.dialogTarget.open, false)
  assert.deepEqual(calls, [])
})
