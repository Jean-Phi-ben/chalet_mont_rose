import { Controller } from "@hotwired/stimulus"

// Modale accessible : ouverture/fermeture animées, Échap, clic sur le fond,
// focus placé dans la boîte à l'ouverture, piège à focus (Tab), retour du
// focus à l'élément déclencheur à la fermeture.
const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export default class extends Controller {
  static targets = ["root", "dialog", "backdrop"]
  static values  = { open: Boolean }

  connect() {
    this._onKey = (e) => {
      if (e.key === "Escape") return this.close()
      if (e.key === "Tab") this._trapFocus(e)
    }
    // Accueil re-rendu après une demande invalide : la modale se rouvre avec la saisie.
    if (this.openValue) requestAnimationFrame(() => this.open())
  }

  open(event) {
    if (event) event.preventDefault()
    if (!this.hasRootTarget) return
    this._opener = document.activeElement
    this.rootTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.backdropTarget.classList.remove("opacity-0")
      this.dialogTarget.classList.remove("opacity-0", "translate-y-4", "scale-95")
      const first = this.dialogTarget.querySelector("[autofocus]") || this._focusables()[0]
      first?.focus()
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
    if (this._opener?.focus) this._opener.focus()
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  _focusables() {
    return Array.from(this.dialogTarget.querySelectorAll(FOCUSABLE)).filter((el) => el.offsetParent !== null)
  }

  // Tab / Maj+Tab restent dans la boîte de dialogue.
  _trapFocus(event) {
    const items = this._focusables()
    if (items.length === 0) return
    const first = items[0], last = items[items.length - 1]
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
  }
}
