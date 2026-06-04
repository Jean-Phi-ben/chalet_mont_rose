# Calculs de tarification — location à la semaine, du samedi au samedi.
# Tous les montants sont en centimes.
class Pricing
  def self.deposit_rate
    (ENV["DEPOSIT_RATE"] || "0.30").to_f
  end

  # Samedi de début de la semaine contenant `date` (samedi le plus proche, <= date).
  def self.week_start_for(date)
    date - ((date.wday - 6) % 7)
  end

  # Tarif (WeeklyRate) de la semaine contenant `date`, ou nil.
  def self.rate_for(date)
    WeeklyRate.find_by(week_start: week_start_for(date))
  end

  # Prix indicatif par nuit pour le jour donné, ou nil si non tarifé.
  def self.nightly_cents_for(date)
    rate_for(date)&.nightly_cents
  end

  # Liste des samedis (week_start) couverts par la période [check_in, check_out).
  def self.weeks_between(check_in, check_out)
    weeks = []
    day = check_in
    while day < check_out
      weeks << day
      day += 7
    end
    weeks
  end

  # Devis pour une période. Renvoie un hash sérialisable en JSON.
  # `guests_count` est utilisé pour la taxe de séjour.
  # `except_id` permet d'exclure une réservation existante (utile à l'admin lors d'un édit).
  def self.quote(check_in, check_out, guests_count: 1, except_id: nil)
    return { bookable: false, reason: "dates_manquantes" } if check_in.nil? || check_out.nil?
    return { bookable: false, reason: "samedi_requis" } unless check_in.saturday? && check_out.saturday?
    return { bookable: false, reason: "ordre_invalide" } unless check_out > check_in

    week_starts = weeks_between(check_in, check_out)
    rates = week_starts.map { |s| WeeklyRate.find_by(week_start: s) }

    return { bookable: false, reason: "semaine_non_tarifee" } if rates.any?(&:nil?)
    return { bookable: false, reason: "semaine_indisponible" } if Booking.confirmed_overlap?(check_in, check_out, except_id: except_id)

    weeks   = week_starts.size
    nights  = (check_out - check_in).to_i
    setting = BookingSetting.current

    accommodation_cents = rates.sum(&:price_cents)
    cleaning_cents      = setting.cleaning_fee_cents * weeks
    tax_cents           = setting.tourist_tax_per_person_per_night_cents * guests_count.to_i * nights
    total_cents         = accommodation_cents + cleaning_cents + tax_cents

    {
      bookable: true,
      check_in: check_in.iso8601,
      check_out: check_out.iso8601,
      weeks: weeks,
      nights: nights,
      accommodation_cents: accommodation_cents,
      cleaning_cents: cleaning_cents,
      tax_cents: tax_cents,
      total_cents: total_cents,
      deposit_cents: (accommodation_cents * deposit_rate).round
    }
  end
end
