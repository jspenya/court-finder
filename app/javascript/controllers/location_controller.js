import { Controller } from "@hotwired/stimulus"

const preferenceKey = "court-finder.location-permission"
let sessionPreference

export default class extends Controller {
  static targets = ["status"]

  async connect() {
    const requestId = this.requestId = (this.requestId || 0) + 1
    delete this.element.currentPosition
    this.dispatch("changed")
    if (!navigator.geolocation) {
      this.statusTarget.textContent = "Location is unavailable in this browser. You can still check all venues."
      return
    }

    let permission
    try {
      permission = (await navigator.permissions.query({ name: "geolocation" })).state
    } catch {
      // Some browsers do not support querying geolocation permission.
    }
    if (requestId !== this.requestId) return

    const preference = this.preference()
    if (permission === "denied") {
      this.remember("denied")
      this.withoutLocation()
    } else if (permission === "granted" || (!permission && preference === "granted") || !preference) {
      this.locate()
    } else {
      this.withoutLocation()
    }
  }

  disconnect() {
    this.requestId = (this.requestId || 0) + 1
    delete this.element.currentPosition
  }

  locate() {
    const requestId = this.requestId = (this.requestId || 0) + 1
    // Remember the attempt too, so dismissing a prompt does not cause repeated requests.
    if (this.preference() !== "granted") this.remember("requested")
    this.statusTarget.textContent = "Waiting for your location… Your location stays in this page."
    navigator.geolocation.getCurrentPosition(({ coords }) => {
      if (requestId !== this.requestId) return
      this.remember("granted")
      this.element.currentPosition = { latitude: coords.latitude, longitude: coords.longitude }
      this.statusTarget.textContent = "Closest venues first · straight-line distances. Change location permission in your browser’s site settings."
      this.dispatch("changed")
    }, (error) => {
      if (requestId !== this.requestId) return
      if (error.code === 1) {
        this.remember("denied")
        this.withoutLocation()
      } else {
        this.statusTarget.textContent = "We couldn’t get your location. You can still check all venues. Reload to try again."
      }
    }, { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 })
  }

  withoutLocation() {
    this.statusTarget.textContent = "Showing all venues. To show closest venues first, allow location in your browser’s site settings and reload."
  }

  preference() {
    try {
      return localStorage.getItem(preferenceKey) || sessionPreference
    } catch {
      return sessionPreference
    }
  }

  remember(value) {
    sessionPreference = value
    try {
      localStorage.setItem(preferenceKey, value)
    } catch {
      // Keep the choice for this session when browser storage is unavailable.
    }
  }
}
