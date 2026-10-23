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

test('preset clicks highlight selected periods without the removed hint element', () => {
  const subject = picker()
  subject.draft = { date: '2026-10-25', playTime: '00:00', playTimeEnd: '00:00', dayParts: [] }
  subject.committed = { ...subject.draft }
  subject.syncPickersFromDraft = () => {}
  subject.updateTriggerLabel = () => {}
  for (const target of ['dateFieldTarget', 'dayPartsFieldTarget', 'playTimeFieldTarget', 'playTimeEndFieldTarget']) {
    subject[target] = {}
  }
  Object.defineProperty(subject, 'stackHintTarget', { get() { throw new Error('Missing target element') } })
  subject.presetTargets = [
    ['', '00:00', '00:00'],
    ['morning', '08:00', '12:00'],
    ['afternoon', '12:00', '17:00'],
    ['evening', '17:00', '00:00']
  ].map(([part, start, end]) => {
    const button = { dataset: { playWindowPickerPartParam: part, playWindowPickerStartParam: start, playWindowPickerEndParam: end } }
    button.classList = { toggle(_name, active) { button.active = active } }
    button.setAttribute = (name, value) => { button[name] = value }
    return button
  })
  const click = part => subject.applyPreset({ params: { part }, stopPropagation() {} })
  const active = () => subject.presetTargets.filter(button => button.active).map(button => button.dataset.playWindowPickerPartParam)

  click('afternoon')
  assert.deepEqual(active(), ['afternoon'])
  click('evening')
  assert.deepEqual(active(), ['afternoon', 'evening'])
  assert.equal(subject.dayPartsFieldTarget.value, 'afternoon,evening')
  assert.equal(subject.presetTargets[3]['aria-pressed'], 'true')
  click('afternoon')
  assert.deepEqual(active(), ['evening'])
  assert.equal(subject.presetTargets[2]['aria-pressed'], 'false')
  click('')
  assert.deepEqual(active(), [''])
})
