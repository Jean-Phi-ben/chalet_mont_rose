import { Controller } from "@hotwired/stimulus"

// Dropdown autonome (sans dépendance FlyonUI) pour le menu « espace client » du desktop.
export default class extends Controller {
  static targets = ["menu", "button", "chevron"]

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
    this._sync()
  }

  close() {
    if (this.menuTarget.classList.contains("hidden")) return
    this.menuTarget.classList.add("hidden")
    this._sync()
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  _sync() {
    const open = !this.menuTarget.classList.contains("hidden")
    this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
    if (this.hasChevronTarget) this.chevronTarget.classList.toggle("rotate-180", open)
  }
}
