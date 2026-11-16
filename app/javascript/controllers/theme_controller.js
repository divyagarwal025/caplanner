import { Controller } from "@hotwired/stimulus"

// Toggles light/dark theme and remembers the choice.
export default class extends Controller {
  static targets = ["icon"]

  connect() {
    const saved = this.read()
    if (saved) document.documentElement.setAttribute("data-theme", saved)
    this.sync()
  }

  toggle() {
    const current = document.documentElement.getAttribute("data-theme")
    const next = current === "dark" ? "light" : "dark"
    document.documentElement.setAttribute("data-theme", next)
    this.write(next)
    this.sync()
  }

  sync() {
    if (!this.hasIconTarget) return
    const dark = document.documentElement.getAttribute("data-theme") === "dark"
    this.iconTarget.textContent = dark ? "☀️" : "🌙"
  }

  read() {
    try { return localStorage.getItem("theme") } catch (_) { return null }
  }
  write(v) {
    try { localStorage.setItem("theme", v) } catch (_) {}
  }
}
