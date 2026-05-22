import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Force FlyonUI à reconnaître ce nouvel élément
    if (window.HSStaticMethods) {
      window.HSStaticMethods.autoInit();
    }
  }
}