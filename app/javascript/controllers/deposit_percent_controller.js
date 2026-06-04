import { Controller } from "@hotwired/stimulus"

// Affiche en temps réel le pourcentage que représentent les arrhes
// par rapport au prix d'hébergement saisi (ou snapshoté).
export default class extends Controller {
  static targets = ["accommodation", "deposit", "hint"]
  static values  = { accommodationCents: Number }

  connect() {
    this.render()
  }

  accommodationChanged() { this.render() }
  depositChanged()       { this.render() }

  render() {
    if (!this.hasHintTarget) return
    const acc = this.currentAccommodationEuros()
    const dep = this.currentDepositEuros()

    if (!acc || acc <= 0) {
      this.hintTarget.textContent = "Défaut : 30 % de l'hébergement"
      return
    }
    if (dep == null) {
      this.hintTarget.textContent = "Défaut : 30 % de l'hébergement"
      return
    }
    const pct = (dep / acc * 100).toFixed(1).replace(/\.0$/, "")
    this.hintTarget.innerHTML = `Cela représente <strong>${pct} %</strong> de l'hébergement`
  }

  currentAccommodationEuros() {
    const raw = this.hasAccommodationTarget && this.accommodationTarget.value.trim()
    if (raw) return parseFloat(raw)
    return (this.accommodationCentsValue || 0) / 100
  }

  currentDepositEuros() {
    const raw = this.hasDepositTarget && this.depositTarget.value.trim()
    if (raw) return parseFloat(raw)
    return null
  }
}
