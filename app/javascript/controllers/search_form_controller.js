import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "results", "submit"]
  static values = { shareUrl: String }

  showLoading(event) {
    this.updateUrl(event.target)
    this.loadingTarget.hidden = false
    this.submitTarget.disabled = true
    this.resultsTarget.replaceChildren()
  }

  hideLoading() {
    this.loadingTarget.hidden = true
    this.submitTarget.disabled = false
  }

  updateUrl(form) {
    const formData = new FormData(form)
    const url = new URL(this.shareUrlValue, window.location.origin)

    url.searchParams.set("date", formData.get("search[date]"))
    url.searchParams.set("play_time", formData.get("search[play_time]"))
    url.searchParams.set("play_time_end", formData.get("search[play_time_end]"))

    window.history.replaceState(window.history.state, "", url)
  }
}
