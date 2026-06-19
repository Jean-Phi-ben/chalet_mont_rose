# Période semestrielle de collecte de la taxe de séjour à reverser.
#   summer = 1er mai → 30 septembre
#   winter = 1er octobre → 30 avril (de l'année suivante)
# Une période n'est listée qu'une fois entièrement passée. Un enregistrement n'est créé
# qu'au moment où l'admin coche la case « payée » (lazy create dans le contrôleur).
class TouristTaxPeriod < ApplicationRecord
  SEASONS = %w[summer winter].freeze

  validates :season, presence: true, inclusion: { in: SEASONS }
  validates :year,   presence: true, numericality: { only_integer: true }
  validates :year,   uniqueness: { scope: :season }

  def summer? = season == "summer"
  def winter? = season == "winter"

  def range
    if summer?
      Date.new(year, 5, 1)..Date.new(year, 9, 30)
    else
      Date.new(year, 10, 1)..Date.new(year + 1, 4, 30)
    end
  end

  def label
    summer? ? "1er mai → 30 septembre #{year}" : "1er octobre #{year} → 30 avril #{year + 1}"
  end

  def completed?
    Date.current > range.end
  end

  # Cumul des taxes de séjour des réservations dont check_in tombe dans la période
  # ET dont les DEUX factures (arrhes + solde) sont marquées « reçues ».
  def tax_total_cents
    fully_paid_ids = Invoice
                       .where(status: Invoice.statuses[:received])
                       .group(:booking_id)
                       .having("COUNT(DISTINCT kind) = 2")
                       .pluck(:booking_id)

    Booking
      .where(id: fully_paid_ids)
      .where(check_in: range)
      .sum(:tourist_tax_cents)
  end

  # Toutes les périodes passées chronologiquement, depuis la plus ancienne réservation.
  # Les périodes non encore cochées sont retournées en mémoire (non persistées).
  def self.completed_periods
    earliest = Booking.minimum(:check_in)
    return [] unless earliest

    today    = Date.current
    periods  = []

    (earliest.year..today.year).each do |y|
      periods << find_or_initialize_by(season: "summer", year: y) if today > Date.new(y, 9, 30)
      periods << find_or_initialize_by(season: "winter", year: y) if today > Date.new(y + 1, 4, 30)
    end

    periods.sort_by { |p| [ p.year, p.summer? ? 0 : 1 ] }
  end
end
