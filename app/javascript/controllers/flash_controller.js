import { Controller } from "@hotwired/stimulus"

// Bannière de message (notice / alert) : le bouton « Fermer » la retire.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
