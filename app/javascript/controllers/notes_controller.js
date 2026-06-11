import { Controller } from "@hotwired/stimulus"

const MONTHS = ["janvier", "février", "mars", "avril", "mai", "juin",
                "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

// Remplit le modal d'édition depuis la ligne cliquée et gère le mini-calendrier
// d'échéance (même esprit que le sélecteur de dates des réservations, en plus léger).
export default class extends Controller {
  static targets = ["form", "title", "body", "deadlineField", "deadlineLabel",
                    "calendar", "monthLabel", "grid"]

  connect() {
    this.view = this._startOfMonth(new Date())
    this.selected = null
  }

  // Pré-remplit le formulaire du modal avant ouverture.
  edit(event) {
    const { url, title, body, deadline } = event.params
    this.formTarget.action = url
    this.titleTarget.value = title || ""
    this.bodyTarget.value = body || ""
    this._setSelected(deadline ? this._parseISO(deadline) : null)
    this.calendarTarget.classList.add("hidden")
  }

  toggleCalendar(event) {
    event.preventDefault()
    this.calendarTarget.classList.toggle("hidden")
    if (!this.calendarTarget.classList.contains("hidden")) this._render()
  }

  prevMonth(event) {
    event.preventDefault()
    this.view = this._addMonths(this.view, -1)
    this._render()
  }

  nextMonth(event) {
    event.preventDefault()
    this.view = this._addMonths(this.view, 1)
    this._render()
  }

  selectDay(event) {
    this._setSelected(this._parseISO(event.currentTarget.dataset.date))
    this.calendarTarget.classList.add("hidden")
  }

  clearDeadline(event) {
    event.preventDefault()
    this._setSelected(null)
    this.calendarTarget.classList.add("hidden")
  }

  _setSelected(date) {
    this.selected = date
    if (date) {
      this.deadlineFieldTarget.value = this._toISO(date)
      this.deadlineLabelTarget.textContent = `${date.getDate()} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`
      this.deadlineLabelTarget.classList.replace("text-stone-400", "text-stone-800")
      this.view = this._startOfMonth(date)
    } else {
      this.deadlineFieldTarget.value = ""
      this.deadlineLabelTarget.textContent = "Aucune échéance"
      this.deadlineLabelTarget.classList.replace("text-stone-800", "text-stone-400")
    }
  }

  _render() {
    this.monthLabelTarget.textContent = `${MONTHS[this.view.getMonth()]} ${this.view.getFullYear()}`
    const year = this.view.getFullYear()
    const month = this.view.getMonth()
    const lead = (new Date(year, month, 1).getDay() + 6) % 7 // lundi = 0
    const days = new Date(year, month + 1, 0).getDate()
    const today = this._toISO(new Date())
    const sel = this.selected ? this._toISO(this.selected) : null

    let html = ""
    for (let i = 0; i < lead; i++) html += "<div></div>"
    for (let d = 1; d <= days; d++) {
      const iso = this._toISO(new Date(year, month, d))
      let cls = "text-stone-600 hover:bg-stone-100"
      if (iso === sel) cls = "bg-stone-900 text-white"
      else if (iso === today) cls = "text-stone-900 font-semibold ring-1 ring-stone-300"
      html += `<button type="button" data-action="notes#selectDay" data-date="${iso}" ` +
              `class="h-9 rounded-lg text-sm transition ${cls}">${d}</button>`
    }
    this.gridTarget.innerHTML = html
  }

  _startOfMonth(d) { return new Date(d.getFullYear(), d.getMonth(), 1) }
  _addMonths(d, n) { return new Date(d.getFullYear(), d.getMonth() + n, 1) }
  _parseISO(s) { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d) }
  _toISO(d) {
    const m = String(d.getMonth() + 1).padStart(2, "0")
    const day = String(d.getDate()).padStart(2, "0")
    return `${d.getFullYear()}-${m}-${day}`
  }
}
