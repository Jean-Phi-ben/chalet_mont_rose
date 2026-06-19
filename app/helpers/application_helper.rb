module ApplicationHelper
  FR_MONTHS = %w[_ janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze
  FR_DAYS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze

  # Format français court : "23 mai 2026".
  def fr_date(date)
    return "" if date.blank?

    "#{date.day} #{FR_MONTHS[date.month]} #{date.year}"
  end

  # Format français avec jour : "samedi 23 mai 2026".
  def fr_date_full(date)
    return "" if date.blank?

    "#{FR_DAYS[date.wday]} #{fr_date(date)}"
  end

  # "mai 2026"
  def fr_month_year(date)
    "#{FR_MONTHS[date.month]} #{date.year}"
  end

  # Petite pastille « En attente » / « Reçue(s) » pour les statuts de paiement de facture.
  def payment_status_chip(received, label)
    cls = received ? "bg-emerald-50 text-emerald-700 border-emerald-200" : "bg-amber-50 text-amber-700 border-amber-200"
    tag.span(label, class: "text-[10px] uppercase tracking-widest px-2 py-0.5 rounded-full border #{cls}")
  end

  # Liste des mois à afficher dans le calendrier empilé front-office :
  # du mois courant jusqu'au dernier mois tarifé, avec un minimum de 12 mois.
  def calendar_months
    first       = Date.current.beginning_of_month
    last_priced = WeeklyRate.maximum(:week_start)&.beginning_of_month
    last        = [ last_priced, first >> 11 ].compact.max
    span        = (last.year - first.year) * 12 + (last.month - first.month)
    (0..span).map { |i| first >> i }
  end

  # Teinte transparente d'une ligne selon les vacances scolaires qui chevauchent
  # la semaine (FR = bleu, CH/Genève = rouge, les deux = dégradé diagonal).
  def holiday_tint_style(france:, geneva:)
    fr_color = "rgba(37, 99, 235, 0.10)"
    ch_color = "rgba(220, 38, 38, 0.10)"

    if france && geneva
      "background-image: linear-gradient(135deg, #{fr_color} 0 50%, #{ch_color} 50% 100%);"
    elsif france
      "background-color: #{fr_color};"
    elsif geneva
      "background-color: #{ch_color};"
    end
  end
end
