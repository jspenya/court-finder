import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "submit"]

  showLoading() {
    this.loadingTarget.hidden = false
    this.submitTarget.disabled = true
  }

  hideLoading() {
    this.loadingTarget.hidden = true
    this.submitTarget.disabled = false
  }
}
