import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "results", "submit"]

  showLoading() {
    this.loadingTarget.hidden = false
    this.submitTarget.disabled = true
    this.resultsTarget.replaceChildren()
  }

  hideLoading() {
    this.loadingTarget.hidden = true
    this.submitTarget.disabled = false
  }
}
