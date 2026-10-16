import { Controller } from "@hotwired/stimulus"

// Font Awesome (version gratuite) n'a pas de télésiège : câble, perche, siège et repose-pieds.
const CHAIRLIFT_SVG = '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2" ' +
  'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
  '<path d="M2 6 22 2"/><path d="M12 4v6"/><path d="M12 10H8v6h9"/><path d="M17 16v3"/></svg>'

// Carte de localisation du chalet, fond topographique (relief + courbes de niveau).
// Leaflet est importé à la demande : il n'est chargé que sur les pages qui ont une carte.
export default class extends Controller {
  static targets = ["canvas"]
  // places : repères secondaires [{ lat, lng, label, detail, icon, side }]
  // icon = classe Font Awesome ou "chairlift" ; side = "left" pour mettre l'étiquette à gauche.
  static values = { lat: Number, lng: Number, zoom: { type: Number, default: 13 }, label: String, places: Array }

  async connect() {
    const { default: L } = await import("leaflet")
    if (!this.element.isConnected || this.map) return

    const center = [this.latValue, this.lngValue]
    // Même zoom sur mobile : en dessous, les repères proches (télésiège, Bettex) se chevauchent.
    this.map = L.map(this.canvasTarget, {
      center,
      zoom: this.zoomValue,
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
    L.marker(center, { icon, title: this.labelValue, zIndexOffset: 1000 }).addTo(this.map)
      .bindPopup(`<strong>${this.labelValue}</strong>`)

    this.placesValue.forEach((place) => this.addPlace(L, place))

    this.map.on("click", () => this.map.scrollWheelZoom.enable())
    this.map.on("mouseout", () => this.map.scrollWheelZoom.disable())
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }

  // Repère secondaire : pastille avec picto + étiquette (largeur libre). Le point exact est
  // le centre du picto ; à gauche, l'étiquette passe devant le picto (flex-row-reverse) et
  // le marqueur est décalé de sa largeur une fois rendu.
  addPlace(L, { lat, lng, label, detail, icon, side }) {
    const left = side === "left"
    const glyph = icon === "chairlift"
      ? CHAIRLIFT_SVG
      : `<i class="fa-solid ${this.escape(icon || "fa-location-dot")} text-xs"></i>`
    const html = `
      <div class="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full bg-white/95 py-1 shadow-md ring-1 ring-stone-200 ${left ? "flex-row-reverse pr-1 pl-3 text-right" : "pl-1 pr-3"}">
        <span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-sky-700 text-white">${glyph}</span>
        <span class="text-[11px] leading-tight text-stone-800">
          <strong class="font-semibold">${this.escape(label)}</strong>
          ${detail ? `<br><span class="text-stone-500">${this.escape(detail)}</span>` : ""}
        </span>
      </div>`
    const divIcon = L.divIcon({ className: "", html, iconSize: null, iconAnchor: [18, 18] })
    const marker = L.marker([lat, lng], { icon: divIcon, title: [label, detail].filter(Boolean).join(" — ") }).addTo(this.map)
    // Étiquette à gauche : le picto est au bout droit de la pastille → ancrage sur cette largeur.
    if (left) {
      const el = marker.getElement()
      el.style.marginLeft = `${18 - el.offsetWidth}px`
    }
  }

  escape(text) {
    return String(text ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c])
  }
}
