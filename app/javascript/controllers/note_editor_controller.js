import { Controller } from "@hotwired/stimulus"

// Populates the shared note modal from the clicked row before it opens.
export default class extends Controller {
  static targets = ["form", "note", "label"]

  prepare(event) {
    const { url, note, label } = event.params
    this.formTarget.action = url
    this.noteTarget.value = note || ""
    if (this.hasLabelTarget) this.labelTarget.textContent = label || ""
  }
}
