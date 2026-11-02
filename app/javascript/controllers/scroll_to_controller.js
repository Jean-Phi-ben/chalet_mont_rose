import { Controller } from "@hotwired/stimulus"

// Zone déroulante (« scroller ») qui s'ouvre sur l'élément « anchor » (ex. la semaine en cours
// de la liste des tarifs), ou à défaut sur le premier « fallback » (première semaine à venir).
// `jump` sert aussi au bouton « Aujourd'hui ». Un en-tête collant (thead / [data-scroll-to-header])
// est pris en compte. À l'ouverture, ne fait rien si l'URL vise déjà une ancre.
export default class extends Controller {
  static targets = ["scroller", "anchor", "fallback"]

  connect() {
    if (window.location.hash) return
    this.jump({ behavior: "instant" })
  }

  jump(options = {}) {
    const target = this.anchorTargets[0] || this.fallbackTargets[0]
    if (!target || !this.hasScrollerTarget) return
    const scroller = this.scrollerTarget
    const header = scroller.querySelector("thead, [data-scroll-to-header]")
    const top = target.getBoundingClientRect().top - scroller.getBoundingClientRect().top
                + scroller.scrollTop - (header ? header.offsetHeight : 0)
    scroller.scrollTo({ top: Math.max(0, top), behavior: options.behavior || "smooth" })
  }
}
