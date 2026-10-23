import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count", "meta", "empty", "list", "progress"]
  static values = {
    venueCount: Number,
    playTime: String
  }

  connect() {
    this.locationElement = this.element.closest('[data-controller~="location"]')
    this.boundLocationChanged = this.locationChanged.bind(this)
    this.locationElement?.addEventListener("location:changed", this.boundLocationChanged)
    this.boundBeforeFrameRender = (event) => {
      // Turbo replaces frame contents, but does not copy response frame attributes.
      const incoming = event.detail.newFrame
      for (const key of ["status", "checkedAt", "earliestSlot", "venueName"]) {
        event.target.dataset[key] = incoming.dataset[key] || ""
      }
    }
    this.element.addEventListener("turbo:before-frame-render", this.boundBeforeFrameRender)
    this.boundFrameLoaded = this.frameLoaded.bind(this)
    this.element.addEventListener("turbo:frame-load", this.boundFrameLoaded)
    this.locationChanged()
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.boundFrameLoaded)
    this.element.removeEventListener("turbo:before-frame-render", this.boundBeforeFrameRender)
    this.locationElement?.removeEventListener("location:changed", this.boundLocationChanged)
  }

  frameLoaded() {
    this.updateDistances()
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
    if (this.hasProgressTarget) {
      this.progressTarget.hidden = allLoaded
      this.progressTarget.textContent = `${loaded.length} of ${this.venueCountValue} venues checked`
    }

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
    const available = this.framesWithStatus("available").sort((left, right) => this.compareFrames(left, right))
    const errors = this.framesWithStatus("error").sort((left, right) => {
      return (left.dataset.venueName || "").localeCompare(right.dataset.venueName || "")
    })
    const empty = this.framesWithStatus("empty")

    ;[...available, ...errors, ...empty].forEach((frame) => this.listTarget.append(frame))
  }

  locationChanged() {
    this.updateDistances()
    if (this.loadedFrames().length === this.venueCountValue) this.sortFrames()
  }

  geographicDistance(frame) {
    const position = this.locationElement?.currentPosition
    if (!position || !frame.dataset.latitude?.trim() || !frame.dataset.longitude?.trim()) return Infinity
    const latitude = Number(frame.dataset.latitude)
    const longitude = Number(frame.dataset.longitude)
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return Infinity
    const radians = (degrees) => degrees * Math.PI / 180
    const a = Math.sin(radians(latitude - position.latitude) / 2) ** 2 +
      Math.cos(radians(position.latitude)) * Math.cos(radians(latitude)) *
      Math.sin(radians(longitude - position.longitude) / 2) ** 2
    return 6371 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, a))))
  }

  updateDistances() {
    this.frames().forEach((frame) => {
      const label = frame.querySelector("[data-venue-distance]")
      if (!label) return
      label.hidden = !this.locationElement?.currentPosition
      const distance = this.geographicDistance(frame)
      label.textContent = Number.isFinite(distance) ? `${distance.toFixed(1)} km away · straight line` : "Distance unavailable"
    })
  }

  compareFrames(left, right) {
    if (this.locationElement?.currentPosition) {
      const difference = this.geographicDistance(left) - this.geographicDistance(right)
      if (difference && !Number.isNaN(difference)) return difference
    }
    return this.slotDistance(left) - this.slotDistance(right) ||
      (left.dataset.venueName || "").localeCompare(right.dataset.venueName || "")
  }

  slotDistance(frame) {
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
