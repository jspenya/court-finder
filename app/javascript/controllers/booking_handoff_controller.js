import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "link"]

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
  }

  continue() {
    window.open(this.linkTarget.href, "_blank", "noopener,noreferrer")
    this.dialogTarget.close()
  }

  dismissBackdrop(event) {
    if (event.target !== this.dialogTarget) return
    const bounds = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) {
      this.dialogTarget.close()
    }
  }

  restoreFocus() {
    this.linkTarget.focus()
  }

  disconnect() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }
}
