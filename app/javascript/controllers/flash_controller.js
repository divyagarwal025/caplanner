import { Controller } from "@hotwired/stimulus"

// Auto-dismisses the flash message after a few seconds.
export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => {
      this.element.classList.add("hide")
      setTimeout(() => this.element.remove(), 400)
    }, 5000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
