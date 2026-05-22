import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "dot", "counter"]

  connect() {
    this.index = 0
    this._update()
    this._onResize = () => this._update(false)
    window.addEventListener("resize", this._onResize)
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
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
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

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.index + 1} / ${this.slideTargets.length}`
    }
  }
}
