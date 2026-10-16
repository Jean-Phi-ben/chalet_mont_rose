import { Controller } from "@hotwired/stimulus"

// Carte de localisation du chalet, fond topographique (relief + courbes de niveau).
// Leaflet est importé à la demande : il n'est chargé que sur les pages qui ont une carte.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { lat: Number, lng: Number, zoom: { type: Number, default: 13 }, label: String }

  async connect() {
    const { default: L } = await import("leaflet")
    if (!this.element.isConnected || this.map) return

    const center = [this.latValue, this.lngValue]
    // Écran étroit : un cran de dézoom pour garder les repères (Saint-Gervais, Megève…).
    const zoom = window.innerWidth < 640 ? this.zoomValue - 1 : this.zoomValue
    this.map = L.map(this.canvasTarget, {
      center,
      zoom,
      // Sur mobile, un doigt fait défiler la page (pas la carte) ; zoom au pincement.
      dragging: !L.Browser.mobile,
      // La molette ne zoome qu'après un clic sur la carte, pour ne pas piéger le scroll.
      scrollWheelZoom: false
    })

    L.tileLayer("https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png", {
      subdomains: "abc",
      maxZoom: 17,
      attribution: 'Données © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>, SRTM | ' +
                   'Rendu © <a href="https://opentopomap.org">OpenTopoMap</a> (CC-BY-SA)'
    }).addTo(this.map)

    // Marqueur HTML (pas d'images Leaflet à résoudre via l'asset pipeline).
    const icon = L.divIcon({
      className: "",
      html: '<div class="flex items-center justify-center w-10 h-10 rounded-full bg-stone-900 text-white shadow-lg ring-4 ring-white"><i class="fa-solid fa-house text-sm"></i></div>',
      iconSize: [40, 40],
      iconAnchor: [20, 20],
      popupAnchor: [0, -22]
    })
    L.marker(center, { icon, title: this.labelValue }).addTo(this.map)
      .bindPopup(`<strong>${this.labelValue}</strong>`)

    this.map.on("click", () => this.map.scrollWheelZoom.enable())
    this.map.on("mouseout", () => this.map.scrollWheelZoom.disable())
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }
}
