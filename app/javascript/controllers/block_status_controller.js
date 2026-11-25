import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Auto-saves a block's status over AJAX the moment the user picks one — no
// Save button, no page reload. PATCHes the single block and applies the
// Turbo Stream the server returns (which patches the ring / counters / subjects).
//
// data-block-status-url-value   -> /blocks/:date/:index
// data-block-status-token-value -> CSRF token
export default class extends Controller {
  static values = { url: String, token: String }

  async change(event) {
    const status = event.target.value
    const body = new URLSearchParams({ _method: "patch", status })

    try {
      const resp = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.tokenValue,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body
      })
      if (resp.ok) {
        const html = await resp.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (e) {
      // network hiccup — leave the selection as-is; the user can click again.
    }
  }
}
