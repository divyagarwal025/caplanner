import { Controller } from "@hotwired/stimulus"

// Collapses/expands the nav on small screens.
export default class extends Controller {
  static targets = ["nav"]

  toggle() {
    this.navTarget.classList.toggle("open")
  }
}
