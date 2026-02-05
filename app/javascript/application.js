import "@hotwired/turbo-rails"
import "controllers"
import "flyonui"

// Cette fonction réactive les composants FlyonUI à chaque changement de page
document.addEventListener("turbo:load", () => {
  if (typeof HSStaticMethods !== 'undefined') {
    HSStaticMethods.autoInit();
  }
})