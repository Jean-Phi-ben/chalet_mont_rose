import { Controller } from "@hotwired/stimulus"

// Positionne la page, à l'ouverture, sur l'élément « anchor » (ex. la semaine en cours
// de la liste des tarifs), ou à défaut sur le premier « fallback » (première semaine à venir).
// Respecte `scroll-padding-top` (en-tête collant). Ne fait rien si l'URL vise déjà une ancre.
export default class extends Controller {
  static targets = ["anchor", "fallback"]

  connect() {
    if (window.location.hash) return
    const target = this.anchorTargets[0] || this.fallbackTargets[0]
    target?.scrollIntoView({ block: "start", behavior: "instant" })
  }
}
