import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "meta", "empty", "list"]
  static values = {
    venueCount: Number,
    playTime: String
  }

  connect() {
    this.boundFrameLoaded = this.frameLoaded.bind(this)
    this.element.addEventListener("turbo:frame-load", this.boundFrameLoaded)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.boundFrameLoaded)
  }

  frameLoaded() {
    this.updateSummary()
    if (this.loadedFrames().length === this.venueCountValue) {
      this.sortFrames()
    }
  }

  updateSummary() {
    const available = this.framesWithStatus("available")
    const loaded = this.loadedFrames()
    const allLoaded = loaded.length === this.venueCountValue
    const checkedAt = this.latestCheckedAt()

    if (checkedAt) {
      this.metaTarget.hidden = false
      this.metaTarget.textContent = `Checked at ${checkedAt}`
    }

    if (available.length > 0) {
      const noun = available.length === 1 ? "venue" : "venues"
      this.countTarget.hidden = false
      this.countTarget.textContent = `${available.length} ${noun} with availability`
      this.emptyTarget.hidden = true
      return
    }

    if (!allLoaded) {
      this.countTarget.hidden = false
      this.countTarget.textContent = `Checking ${this.venueCountValue} venues…`
      return
    }

    this.countTarget.hidden = true
    this.countTarget.textContent = ""

    if (this.framesWithStatus("error").length > 0) {
      this.emptyTarget.hidden = true
      return
    }

    this.metaTarget.hidden = true
    this.emptyTarget.hidden = false
  }

  sortFrames() {
    const available = this.framesWithStatus("available").sort((left, right) => this.distance(left) - this.distance(right))
    const errors = this.framesWithStatus("error").sort((left, right) => {
      return (left.dataset.venueName || "").localeCompare(right.dataset.venueName || "")
    })
    const empty = this.framesWithStatus("empty")

    ;[...available, ...errors, ...empty].forEach((frame) => this.listTarget.append(frame))
  }

  distance(frame) {
    if (!frame.dataset.earliestSlot || !this.playTimeValue) return Number.POSITIVE_INFINITY

    return Math.abs(new Date(frame.dataset.earliestSlot) - new Date(this.playTimeValue))
  }

  latestCheckedAt() {
    return this.loadedFrames().map((frame) => frame.dataset.checkedAt).find(Boolean)
  }

  loadedFrames() {
    return this.frames().filter((frame) => frame.dataset.status && frame.dataset.status !== "pending")
  }

  framesWithStatus(status) {
    return this.frames().filter((frame) => frame.dataset.status === status)
  }

  frames() {
    return [...this.listTarget.querySelectorAll("turbo-frame")]
  }
}
