import { Controller } from "@hotwired/stimulus"

// Fenêtre modale basée sur <dialog> natif : showModal() gère le focus, la touche
// Échap et l'arrière-plan. Un clic hors du contenu (sur le fond) ferme aussi.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    if (event) event.preventDefault()
    this.dialogTarget.showModal()
  }

  close(event) {
    if (event) event.preventDefault()
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
