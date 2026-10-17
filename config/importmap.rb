pin "application", to: "application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "flyonui", to: "flyonui.js", preload: true
# Carte de localisation (page d'accueil) : importée à la demande par map_controller,
# donc pas de préchargement sur les autres pages.
pin "leaflet", preload: false # @1.9.4
# Tracé de signature (page de signature du contrat), importé à la demande.
pin "signature_pad", preload: false # @5.1.1 — vendor/javascript (build ESM, licence MIT)
