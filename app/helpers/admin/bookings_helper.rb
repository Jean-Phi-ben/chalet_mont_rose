module Admin::BookingsHelper
  PAYMENT_PILL_CLASSES = {
    ok:      "bg-emerald-50 text-emerald-700 border-emerald-200",
    waiting: "bg-amber-50 text-amber-700 border-amber-200",
    ko:      "bg-rose-50 text-rose-700 border-rose-200",
    none:    "bg-stone-50 text-stone-400 border-stone-200"
  }.freeze

  # Petite pastille colorée pour la colonne "Paiements" du tableau bookings.
  def payment_pill(label, state, title: nil)
    classes = PAYMENT_PILL_CLASSES.fetch(state, PAYMENT_PILL_CLASSES[:none])
    tag.span(label,
             class: "inline-block text-[10px] uppercase tracking-widest px-2 py-0.5 rounded-full border #{classes}",
             title: title)
  end

  # État de paiement d'une Invoice (arrhes / solde).
  def invoice_state(invoice)
    return :none unless invoice
    invoice.payment_received? ? :ok : :waiting
  end

  # État de la caution Swikly.
  def caution_state(caution)
    return :none unless caution
    case caution.status
    when "accepted", "released" then :ok
    when "pending"              then :waiting
    when "declined", "captured" then :ko
    else                             :none
    end
  end
end
