import { Controller } from "@hotwired/stimulus"

// Drives the EURA chat: clears the input after a message is sent and keeps the
// log scrolled to the newest bubble. The actual send is a Turbo-powered form.
export default class extends Controller {
  static targets = ["log", "input"]

  connect() {
    this.scrollToEnd()
    // Keep scrolled as Turbo appends new bubbles to the log.
    if (this.hasLogTarget) {
      this.observer = new MutationObserver(() => this.scrollToEnd())
      this.observer.observe(this.logTarget, { childList: true })
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  // Fired on turbo:submit-end (form submitted). Clear input, refocus.
  sent(event) {
    if (event.detail?.success === false) return
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
  }

  scrollToEnd() {
    if (this.hasLogTarget) this.logTarget.scrollTop = this.logTarget.scrollHeight
  }
}
