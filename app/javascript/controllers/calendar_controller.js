import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["day", "summary", "total", "deposit", "nights", "reserve", "message",
                    "checkIn", "checkOut", "recapDates", "recapNights", "recapTotal", "recapDeposit",
                    "recapCleaning", "recapTax", "picker", "pickerPanel", "pickerBackdrop",
                    "datesLabel", "pickerInfo", "confirm", "submit", "guests",
                    "accommodationPlaceholder"]
  static values = { quoteUrl: String }

  connect() {
    this.checkIn = null
    this.checkOut = null
  }

  // --- Sélecteur de dates (overlay au-dessus de la modale) ---

  openPicker(event) {
    if (event) event.preventDefault()
    if (!this.hasPickerTarget) return

    this.pickerTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.pickerTarget.classList.remove("opacity-0")
      if (this.hasPickerPanelTarget) this.pickerPanelTarget.classList.remove("opacity-0", "translate-y-4", "scale-95")
    })
  }

  closePicker(event) {
    if (event) event.preventDefault()
    if (!this.hasPickerTarget) return

    this.pickerTarget.classList.add("opacity-0")
    if (this.hasPickerPanelTarget) this.pickerPanelTarget.classList.add("opacity-0", "translate-y-4", "scale-95")
    setTimeout(() => this.pickerTarget.classList.add("hidden"), 250)
  }

  backdropClosePicker(event) {
    if (this.hasPickerBackdropTarget && event.target === this.pickerBackdropTarget) this.closePicker()
  }

  // --- Sélection des jours ---

  pick(event) {
    const iso = event.currentTarget.dataset.date
    if (!iso) return

    const isFirstPick = !this.checkIn || this.checkOut

    if (isFirstPick) {
      this.checkIn = this.snapBackToSaturday(iso)
      this.checkOut = null
    } else {
      const candidate = this.snapForwardToSaturday(iso, this.checkIn)
      if (candidate <= this.checkIn) {
        this.checkIn = this.snapBackToSaturday(iso)
        this.checkOut = null
      } else {
        this.checkOut = candidate
      }
    }

    this.paint()
    if (this.checkIn && this.checkOut) this.fetchQuote()
    else this.hideSummary()
  }

  // Samedi du même jour ou immédiatement antérieur (pour l'arrivée).
  snapBackToSaturday(iso) {
    const d = new Date(`${iso}T00:00:00`)
    const back = (d.getDay() + 1) % 7
    d.setDate(d.getDate() - back)
    return this.isoOf(d)
  }

  // Samedi du même jour ou immédiatement postérieur (pour le départ).
  // Si on tombe exactement sur la date d'arrivée, on saute au samedi suivant.
  snapForwardToSaturday(iso, checkInIso) {
    const d = new Date(`${iso}T00:00:00`)
    let forward = (6 - d.getDay() + 7) % 7
    if (forward === 0 && this.isoOf(d) === checkInIso) forward = 7
    d.setDate(d.getDate() + forward)
    return this.isoOf(d)
  }

  isoOf(d) {
    const y = d.getFullYear()
    const m = String(d.getMonth() + 1).padStart(2, "0")
    const day = String(d.getDate()).padStart(2, "0")
    return `${y}-${m}-${day}`
  }

  paint() {
    this.dayTargets.forEach((el) => {
      const d = el.dataset.date
      const selected = d === this.checkIn || d === this.checkOut
      const inRange = this.checkIn && this.checkOut && d > this.checkIn && d < this.checkOut
      el.classList.toggle("cal-selected", selected)
      el.classList.toggle("cal-range", Boolean(inRange))
    })
  }

  // Re-déclenché quand on change le nombre de voyageurs (la taxe de séjour en dépend).
  guestsChanged() {
    if (this.checkIn && this.checkOut) this.fetchQuote()
  }

  async fetchQuote() {
    const guests = this.hasGuestsTarget ? parseInt(this.guestsTarget.value || "1", 10) : 1
    const url = `${this.quoteUrlValue}?check_in=${this.checkIn}&check_out=${this.checkOut}&guests=${guests}`
    let data
    try {
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      data = await res.json()
    } catch (_e) {
      return this.showMessage("Impossible de calculer le tarif. Réessayez.")
    }

    if (!data.bookable) return this.showMessage(this.reason(data.reason))

    if (this.hasCheckInTarget) this.checkInTarget.value = this.checkIn
    if (this.hasCheckOutTarget) this.checkOutTarget.value = this.checkOut

    const range = `${this.frDate(this.checkIn)} → ${this.frDate(this.checkOut)}`
    if (this.hasTotalTarget) this.totalTarget.textContent = this.euros(data.total_cents)
    if (this.hasDepositTarget) this.depositTarget.textContent = this.euros(data.deposit_cents)
    if (this.hasNightsTarget) this.nightsTarget.textContent = data.nights
    if (this.hasRecapDatesTarget) this.recapDatesTarget.textContent = range
    if (this.hasRecapNightsTarget) this.recapNightsTarget.textContent = data.nights
    if (this.hasRecapTotalTarget) this.recapTotalTarget.textContent = this.euros(data.total_cents)
    if (this.hasRecapDepositTarget) this.recapDepositTarget.textContent = this.euros(data.deposit_cents)
    if (this.hasRecapCleaningTarget) this.recapCleaningTarget.textContent = this.euros(data.cleaning_cents)
    if (this.hasRecapTaxTarget) this.recapTaxTarget.textContent = this.euros(data.tax_cents)
    if (this.hasDatesLabelTarget) this.datesLabelTarget.textContent = range
    if (this.hasPickerInfoTarget) {
      this.pickerInfoTarget.textContent = `${data.nights} nuits · ${this.euros(data.total_cents)} · arrhes ${this.euros(data.deposit_cents)}`
      this.pickerInfoTarget.classList.remove("hidden")
    }

    if (this.hasAccommodationPlaceholderTarget) {
      this.accommodationPlaceholderTarget.placeholder = `Auto · ${this.euros(data.accommodation_cents)}`
    }
    if (this.hasSummaryTarget) this.summaryTarget.classList.remove("hidden")
    if (this.hasMessageTarget) this.messageTarget.classList.add("hidden")
    if (this.hasReserveTarget) this.reserveTarget.classList.remove("hidden")
    if (this.hasConfirmTarget) this.confirmTarget.disabled = false
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  hideSummary() {
    if (this.hasSummaryTarget) this.summaryTarget.classList.add("hidden")
    if (this.hasMessageTarget) this.messageTarget.classList.add("hidden")
    if (this.hasReserveTarget) this.reserveTarget.classList.add("hidden")
    if (this.hasPickerInfoTarget) this.pickerInfoTarget.classList.add("hidden")
    if (this.hasConfirmTarget) this.confirmTarget.disabled = true
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }

  showMessage(text) {
    if (this.hasSummaryTarget) this.summaryTarget.classList.add("hidden")
    if (this.hasReserveTarget) this.reserveTarget.classList.add("hidden")
    if (this.hasPickerInfoTarget) this.pickerInfoTarget.classList.add("hidden")
    if (this.hasConfirmTarget) this.confirmTarget.disabled = true
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = text
      this.messageTarget.classList.remove("hidden")
    }
  }

  euros(cents) {
    return (cents / 100).toLocaleString("fr-FR", {
      style: "currency",
      currency: "EUR",
      maximumFractionDigits: 0
    })
  }

  frDate(iso) {
    return new Date(`${iso}T00:00:00`).toLocaleDateString("fr-FR", {
      day: "numeric",
      month: "short",
      year: "numeric"
    })
  }

  reason(code) {
    return {
      samedi_requis: "Les arrivées et départs se font le samedi.",
      ordre_invalide: "La date de départ doit suivre l'arrivée.",
      semaine_non_tarifee: "Une ou plusieurs semaines ne sont pas disponibles."
    }[code] || "Période indisponible."
  }
}
