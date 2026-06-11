import { Controller } from "@hotwired/stimulus"

// Orchestre la page de signature électronique :
//   - tracking du scroll du contrat (active le bloc signature en bas)
//   - signature_pad sur le canvas (lib UMD chargée via CDN)
//   - validation côté client : scrollé + OTP saisi + tracé + case cochée
//   - sérialise le tracé en base64 PNG dans un champ hidden à la soumission
export default class extends Controller {
  static targets = [
    "document", "scrollHint", "scrollOk", "signBlock",
    "canvas", "otp", "accepted", "submitBtn", "hint",
    "otpHidden", "signatureHidden", "acceptedHidden", "form"
  ]

  static values = { otpSent: Boolean }

  connect() {
    this.scrolledToEnd = false
    this.signaturePadReady = false
    this._setupSignaturePad()
    this._onResize = this._setupCanvasSize.bind(this)
    window.addEventListener("resize", this._onResize)

    // On force toujours le scroll pour valider la lecture du contrat —
    // l'OTP est envoyé automatiquement à l'ouverture mais ne suffit pas
    // à débloquer la signature.
    this._checkInitialScroll()
    this.refresh()
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
  }

  // --- Scroll tracking ----------------------------------------------------

  onScroll() {
    const el = this.documentTarget
    const distanceFromBottom = el.scrollHeight - (el.scrollTop + el.clientHeight)
    if (distanceFromBottom <= 12) this._activateSignBlock()
  }

  _checkInitialScroll() {
    const el = this.documentTarget
    if (el.scrollHeight <= el.clientHeight + 8) this._activateSignBlock()
  }

  _activateSignBlock() {
    if (this.scrolledToEnd) return
    this.scrolledToEnd = true
    this.signBlockTarget.classList.remove("opacity-40", "pointer-events-none")
    this.scrollHintTarget.classList.add("hidden")
    this.scrollOkTarget.classList.remove("hidden")
    this._setupCanvasSize()
    this.refresh()
  }

  // --- Signature pad ------------------------------------------------------

  _setupSignaturePad() {
    if (typeof window.SignaturePad === "undefined") {
      console.error("[contract-signing] SignaturePad SDK non chargé")
      return
    }
    this.pad = new window.SignaturePad(this.canvasTarget, {
      backgroundColor: "rgba(0,0,0,0)",
      penColor: "#1c1917",
      minWidth: 0.8,
      maxWidth: 2.4,
    })
    this.pad.addEventListener("endStroke", () => this.refresh())
    this.signaturePadReady = true
  }

  _setupCanvasSize() {
    if (!this.signaturePadReady) return
    const canvas = this.canvasTarget
    const ratio = Math.max(window.devicePixelRatio || 1, 1)
    const data = this.pad?.toData() || []
    canvas.width  = canvas.offsetWidth  * ratio
    canvas.height = canvas.offsetHeight * ratio
    const ctx = canvas.getContext("2d")
    ctx.scale(ratio, ratio)
    this.pad.clear()
    if (data.length) this.pad.fromData(data)
  }

  clearCanvas() {
    this.pad?.clear()
    this.refresh()
  }

  // --- Validation & soumission --------------------------------------------

  refresh() {
    const hasSignature = this.pad && !this.pad.isEmpty()
    const hasOtp       = this.otpTarget.value.trim().match(/^\d{6}$/) != null
    const hasAccepted  = this.acceptedTarget.checked
    const ready        = this.scrolledToEnd && hasSignature && hasOtp && hasAccepted

    this.submitBtnTarget.disabled = !ready

    // Sync les champs hidden pour POST
    this.otpHiddenTarget.value       = this.otpTarget.value.trim()
    this.signatureHiddenTarget.value = hasSignature ? this.pad.toDataURL("image/png") : ""
    this.acceptedHiddenTarget.value  = hasAccepted ? "1" : "0"

    // Message d'aide contextualisé
    let hint = ""
    if (!this.scrolledToEnd)       hint = "Faites défiler le contrat jusqu'en bas."
    else if (!hasSignature)        hint = "Dessinez votre signature dans le cadre."
    else if (!hasOtp)              hint = "Saisissez votre code à 6 chiffres."
    else if (!hasAccepted)         hint = "Cochez la case d'engagement."
    this.hintTarget.textContent = hint
  }
}
