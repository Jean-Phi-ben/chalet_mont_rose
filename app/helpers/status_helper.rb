# Pastilles et libellés de statut, partagés entre l'admin et l'espace client.
module StatusHelper
  BOOKING_STATUSES = {
    "pending"   => { label: "En attente", long: "En attente de validation", cls: "bg-amber-50 text-amber-700 border-amber-200" },
    "confirmed" => { label: "Confirmée",  long: "Confirmée",                 cls: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    "rejected"  => { label: "Refusée",    long: "Refusée",                   cls: "bg-rose-50 text-rose-700 border-rose-200" },
    "cancelled" => { label: "Annulée",    long: "Annulée",                   cls: "bg-stone-100 text-stone-600 border-stone-200" }
  }.freeze

  CAUTION_STATUSES = {
    "pending"  => "En attente de dépôt",
    "accepted" => "Déposée",
    "released" => "Libérée",
    "captured" => "Encaissée",
    "declined" => "Refusée"
  }.freeze

  def booking_status_label(status, long: false)
    entry = BOOKING_STATUSES.fetch(status.to_s, BOOKING_STATUSES["pending"])
    long ? entry[:long] : entry[:label]
  end

  def booking_status_classes(status)
    BOOKING_STATUSES.fetch(status.to_s, BOOKING_STATUSES["pending"])[:cls]
  end

  # <span> pastille complète.
  def booking_status_badge(booking, long: false, size: :sm, class_name: nil)
    base = size == :lg ? "text-xs px-3 py-1" : "text-[11px] px-2.5 py-0.5"
    tag.span(booking_status_label(booking.status, long: long),
             class: [ base, "uppercase tracking-widest rounded-full border", booking_status_classes(booking.status), class_name ].compact.join(" "))
  end

  def caution_status_label(caution)
    return "Caution non créée" unless caution

    "Caution : #{CAUTION_STATUSES.fetch(caution.status.to_s, caution.status.to_s.humanize).downcase}"
  end
end
