import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = [
    "trigger",
    "triggerLabel",
    "panel",
    "dateField",
    "playTimeField",
    "playTimeEndField",
    "dateInput",
    "playTimeInput",
    "playTimeEndInput",
    "error",
  ]

  static values = {
    minDate: String,
  }

  connect() {
    this.committed = this.readFromFields()
    this.draft = { ...this.committed }
    this.boundCloseOnOutside = this.closeOnOutsideClick.bind(this)
    this.boundKeydown = this.onKeydown.bind(this)

    this.datePicker = flatpickr(this.dateInputTarget, this.dateOptions())
    this.playTimePicker = flatpickr(this.playTimeInputTarget, this.timeOptions(this.playTimeInputTarget, this.committed.playTime, this.playTimeChanged.bind(this)))
    this.playTimeEndPicker = flatpickr(this.playTimeEndInputTarget, this.timeOptions(this.playTimeEndInputTarget, this.committed.playTimeEnd, this.playTimeEndChanged.bind(this)))

    this.updateTriggerLabel()
  }

  disconnect() {
    this.datePicker?.destroy()
    this.playTimePicker?.destroy()
    this.playTimeEndPicker?.destroy()
    this.removeDocumentListeners()
  }

  toggle(event) {
    event.stopPropagation()

    if (this.panelTarget.hidden) {
      this.open()
    } else {
      this.cancel()
    }
  }

  open() {
    this.draft = { ...this.committed }
    this.clearError()
    this.syncPickersFromDraft()
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")

    setTimeout(() => {
      document.addEventListener("click", this.boundCloseOnOutside)
      document.addEventListener("keydown", this.boundKeydown)
    }, 0)
  }

  cancel(event) {
    event?.stopPropagation()
    this.clearError()
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.removeDocumentListeners()
  }

  update(event) {
    event.stopPropagation()

    const error = this.validateDraft()
    if (error) {
      this.showError(error)
      return
    }

    this.committed = { ...this.draft }
    this.writeToFields()
    this.updateTriggerLabel()
    this.cancel()
  }

  dateOptions() {
    return {
      appendTo: this.dateInputTarget.closest(".play-window-picker__date"),
      dateFormat: "Y-m-d",
      defaultDate: this.committed.date,
      disableMobile: true,
      inline: true,
      minDate: this.minDateValue || "today",
      onChange: (_selectedDates, dateStr) => {
        this.draft.date = dateStr
      },
    }
  }

  timeOptions(_input, defaultTime, onChange) {
    return {
      allowInput: false,
      altInput: true,
      altFormat: "h:i K",
      altInputClass: "field__input field__input--picker play-window-picker__input",
      dateFormat: "H:i",
      defaultDate: defaultTime,
      disableMobile: true,
      enableTime: true,
      minuteIncrement: 60,
      noCalendar: true,
      onChange: (_selectedDates, timeStr) => {
        onChange(timeStr)
      },
      onOpen: (_selectedDates, _dateStr, instance) => {
        this.closeOtherTimePickers(instance)
      },
    }
  }

  closeOtherTimePickers(activeInstance) {
    for (const picker of [this.playTimePicker, this.playTimeEndPicker]) {
      if (picker !== activeInstance && picker.isOpen) {
        picker.close()
      }
    }
  }

  playTimeChanged(timeStr) {
    this.draft.playTime = timeStr
  }

  playTimeEndChanged(timeStr) {
    this.draft.playTimeEnd = timeStr
  }

  readFromFields() {
    return {
      date: this.dateFieldTarget.value,
      playTime: this.playTimeFieldTarget.value,
      playTimeEnd: this.playTimeEndFieldTarget.value,
    }
  }

  writeToFields() {
    this.dateFieldTarget.value = this.committed.date
    this.playTimeFieldTarget.value = this.committed.playTime
    this.playTimeEndFieldTarget.value = this.committed.playTimeEnd
  }

  syncPickersFromDraft() {
    this.datePicker.setDate(this.draft.date, false)
    this.playTimePicker.setDate(this.draft.playTime, false)
    this.playTimeEndPicker.setDate(this.draft.playTimeEnd, false)
  }

  validateDraft() {
    const { date, playTime, playTimeEnd } = this.draft

    if (!date || !playTime || !playTimeEnd) {
      return "Select a date and time window"
    }

    if (playTimeEnd <= playTime) {
      return "End time must be after start time"
    }

    return null
  }

  updateTriggerLabel() {
    const { date, playTime, playTimeEnd } = this.committed

    if (!date || !playTime || !playTimeEnd) {
      this.triggerLabelTarget.textContent = "Select when you want to play"
      return
    }

    const parsedDate = flatpickr.parseDate(date, "Y-m-d")
    const dateLabel = parsedDate
      ? flatpickr.formatDate(parsedDate, "l, F j, Y")
      : date

    this.triggerLabelTarget.textContent =
      `${dateLabel} · ${this.formatTime12(playTime)} → ${this.formatTime12(playTimeEnd)}`
  }

  formatTime12(timeStr) {
    const [hourPart, minutePart] = timeStr.split(":")
    const hour = Number.parseInt(hourPart, 10)
    const minute = Number.parseInt(minutePart, 10)
    const period = hour >= 12 ? "PM" : "AM"
    const hour12 = hour % 12 || 12

    return `${hour12}:${String(minute).padStart(2, "0")} ${period}`
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }

  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return
    if (event.target.closest(".flatpickr-calendar")) return

    this.cancel()
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.cancel()
    }
  }

  removeDocumentListeners() {
    document.removeEventListener("click", this.boundCloseOnOutside)
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
