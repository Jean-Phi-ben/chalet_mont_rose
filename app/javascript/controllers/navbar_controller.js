import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle", "iconOpen", "iconClose"]

  connect() {
    this.close()
    this._onResize = this._onResize.bind(this)
    window.addEventListener("resize", this._onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
  }

  toggle() {
    this.menuTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    // Styles inline : Font Awesome (CSS non-layered) impose display:inline-block
    // aux .fa-* et écrase le .hidden de Tailwind v4 (layered). L'inline gagne.
    this.iconOpenTarget.style.display = "none"
    this.iconCloseTarget.style.display = "inline-block"
    this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.iconOpenTarget.style.display = "inline-block"
    this.iconCloseTarget.style.display = "none"
    this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  _onResize() {
    if (window.innerWidth >= 1024) this.close()
  }
}
