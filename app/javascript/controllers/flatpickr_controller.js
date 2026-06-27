import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    mode: { type: String, default: "time" },
    minDate: String,
  }

  connect() {
    this.picker = flatpickr(this.inputTarget, this.options())
  }

  disconnect() {
    this.picker?.destroy()
  }

  options() {
    const base = {
      allowInput: false,
      altInput: true,
      altInputClass: "field__input field__input--picker",
      disableMobile: true,
      clickOpens: true,
      animate: true,
    }

    if (this.modeValue === "date") {
      return {
        ...base,
        dateFormat: "Y-m-d",
        altFormat: "l, F j, Y",
        minDate: this.minDateValue || "today",
      }
    }

    return {
      ...base,
      enableTime: true,
      noCalendar: true,
      dateFormat: "H:i",
      altFormat: "h:i K",
      minuteIncrement: 60,
    }
  }
}
