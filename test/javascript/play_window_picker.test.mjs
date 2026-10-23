import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

function picker() {
  const source = readFileSync(new URL('../../app/javascript/controllers/play_window_picker_controller.js', import.meta.url), 'utf8')
    .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
    .replace('import flatpickr from "flatpickr"', '')
    .replace('export default class', 'globalThis.Subject = class')
  const context = vm.createContext({})
  vm.runInContext(source, context)
  const subject = new context.Subject()
  subject.errorTarget = { textContent: '', hidden: true }
  return subject
}

test('an invalid visible time range cannot submit previously committed hidden fields', () => {
  const subject = picker()
  subject.draft = { date: '2026-10-24', playTime: '16:00', playTimeEnd: '13:00' }
  let prevented = false, stopped = false
  subject.validateSubmission({ preventDefault() { prevented = true }, stopImmediatePropagation() { stopped = true } })
  assert.equal(prevented, true)
  assert.equal(stopped, true)
  assert.equal(subject.errorTarget.hidden, false)
})

test('midnight remains valid as the end of an evening or all-day search', () => {
  for (const playTime of ['17:00', '00:00']) {
    const subject = picker()
    subject.draft = { date: '2026-10-24', playTime, playTimeEnd: '00:00' }
    subject.validateSubmission({ preventDefault() { assert.fail('valid range blocked') } })
  }
})
