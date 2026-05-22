import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["root", "dialog", "backdrop"]

  connect() {
    this._onKey = (e) => { if (e.key === "Escape") this.close() }
  }

  open(event) {
    if (event) event.preventDefault()
    if (!this.hasRootTarget) return
    this.rootTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.backdropTarget.classList.remove("opacity-0")
      this.dialogTarget.classList.remove("opacity-0", "translate-y-4", "scale-95")
    })
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._onKey)
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.hasRootTarget) return
    this.backdropTarget.classList.add("opacity-0")
    this.dialogTarget.classList.add("opacity-0", "translate-y-4", "scale-95")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._onKey)
    setTimeout(() => this.rootTarget.classList.add("hidden"), 250)
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) this.close()
  }
}
