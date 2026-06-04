import { Controller } from "@hotwired/stimulus"

// Submits the form the controller is attached to (used for inline edits).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
