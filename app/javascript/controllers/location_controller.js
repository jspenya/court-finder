import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status", "clear"]

  connect() {
    this.clear()
  }

  disconnect() {
    this.requestId = (this.requestId || 0) + 1
    delete this.element.currentPosition
  }

  locate() {
    if (!navigator.geolocation) {
      this.statusTarget.textContent = "Location is unavailable in this browser. You can still check all venues."
      return
    }

    const requestId = this.requestId = (this.requestId || 0) + 1
    this.buttonTarget.disabled = true
    this.statusTarget.textContent = "Waiting for your location…"
    navigator.geolocation.getCurrentPosition(({ coords }) => {
      if (requestId !== this.requestId) return
      this.element.currentPosition = { latitude: coords.latitude, longitude: coords.longitude }
      this.buttonTarget.disabled = false
      this.clearTarget.hidden = false
      this.statusTarget.textContent = "Closest venues first · straight-line distances. Venues without map positions appear last."
      this.dispatch("changed")
    }, (error) => {
      if (requestId !== this.requestId) return
      this.buttonTarget.disabled = false
      this.statusTarget.textContent = error.code === 1
        ? "Location permission was denied. Allow location in your browser settings to try again, or check all venues."
        : "We couldn’t get your location. Try again, or check all venues."
    }, { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 })
  }

  clear() {
    this.requestId = (this.requestId || 0) + 1
    delete this.element.currentPosition
    this.buttonTarget.disabled = false
    this.clearTarget.hidden = true
    this.statusTarget.textContent = "Share your location to show the closest venues first. Your location stays in this page."
    this.dispatch("changed")
  }
}
