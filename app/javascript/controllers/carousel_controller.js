import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "dot", "counter",
                    "lightbox", "lightboxImage", "lightboxCaption", "lightboxCounter", "lightboxClose"]

  connect() {
    this.index = 0
    this._update()
    this._onResize = () => this._update(false)
    window.addEventListener("resize", this._onResize)
    // Glisser (mobile) : vaut pour le carrousel comme pour le plein écran.
    this._touchStartX = null
    this.element.addEventListener("touchstart", (e) => {
      this._touchStartX = e.touches[0].clientX
    }, { passive: true })
    this.element.addEventListener("touchend", (e) => {
      if (this._touchStartX === null) return
      const delta = e.changedTouches[0].clientX - this._touchStartX
      if (Math.abs(delta) > 40) delta < 0 ? this.next() : this.prev()
      this._touchStartX = null
    })
    this._onKey = (e) => {
      if (e.key === "Escape") this.close()
      else if (e.key === "ArrowRight") this.next()
      else if (e.key === "ArrowLeft") this.prev()
    }
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
    if (this._isOpen()) this.close()
  }

  next() {
    this.index = (this.index + 1) % this.slideTargets.length
    this._update()
  }

  prev() {
    this.index = (this.index - 1 + this.slideTargets.length) % this.slideTargets.length
    this._update()
  }

  goTo(event) {
    const i = parseInt(event.currentTarget.dataset.index, 10)
    if (!Number.isNaN(i)) {
      this.index = i
      this._update()
    }
  }

  // --- Plein écran ---

  open(event) {
    if (!this.hasLightboxTarget) return
    const slide = event?.currentTarget?.closest("[data-carousel-target='slide']")
    const i = slide ? this.slideTargets.indexOf(slide) : -1
    if (i >= 0) this.index = i

    this._returnFocus = document.activeElement
    this.lightboxTarget.classList.remove("hidden")
    requestAnimationFrame(() => this.lightboxTarget.classList.remove("opacity-0"))
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._onKey)
    this._update(false)
    if (this.hasLightboxCloseTarget) this.lightboxCloseTarget.focus()
  }

  close() {
    if (!this._isOpen()) return
    this.lightboxTarget.classList.add("opacity-0")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._onKey)
    setTimeout(() => this.lightboxTarget.classList.add("hidden"), 200)
    this._returnFocus?.focus?.()
  }

  // Clic hors de la photo et des boutons (fond noir) → fermeture.
  backdropClose(event) {
    if (event.target === event.currentTarget || event.target.dataset.lightboxBackdrop !== undefined) this.close()
  }

  _isOpen() {
    return this.hasLightboxTarget && !this.lightboxTarget.classList.contains("hidden")
  }

  _update(animate = true) {
    const slide = this.slideTargets[this.index]
    if (!slide) return
    const offset = slide.offsetLeft
    this.trackTarget.style.transition = animate ? "transform 600ms cubic-bezier(0.22, 1, 0.36, 1)" : "none"
    this.trackTarget.style.transform = `translateX(-${offset}px)`

    this.dotTargets.forEach((dot, i) => {
      const active = i === this.index
      dot.classList.toggle("w-8", active)
      dot.classList.toggle("bg-stone-900", active)
      dot.classList.toggle("w-2", !active)
      dot.classList.toggle("bg-stone-300", !active)
    })

    const label = `${this.index + 1} / ${this.slideTargets.length}`
    if (this.hasCounterTarget) this.counterTarget.textContent = label

    if (this._isOpen()) {
      const img = slide.querySelector("img")
      this.lightboxImageTarget.src = img.currentSrc || img.src
      this.lightboxImageTarget.alt = img.alt
      if (this.hasLightboxCaptionTarget) this.lightboxCaptionTarget.textContent = img.alt
      if (this.hasLightboxCounterTarget) this.lightboxCounterTarget.textContent = label
      this._preloadNeighbours()
    }
  }

  // Charge les photos voisines pour une navigation sans attente en plein écran.
  _preloadNeighbours() {
    const n = this.slideTargets.length
    ;[this.index + 1, this.index - 1].forEach((i) => {
      const img = this.slideTargets[(i + n) % n].querySelector("img")
      if (img) new Image().src = img.currentSrc || img.src
    })
  }
}
