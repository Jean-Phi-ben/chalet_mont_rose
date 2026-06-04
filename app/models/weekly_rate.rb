class WeeklyRate < ApplicationRecord
  validates :week_start, presence: true, uniqueness: true
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :min_weeks, numericality: { greater_than_or_equal_to: 1 }
  validate :week_start_must_be_saturday

  scope :ordered, -> { order(:week_start) }
  scope :upcoming, -> { where("week_start >= ?", Date.current.beginning_of_week(:saturday)) }

  def nightly_cents
    (price_cents / 7.0).round
  end

  # Saisie/affichage en euros (le stockage reste en centimes).
  def price_euros
    price_cents && price_cents / 100.0
  end

  def price_euros=(value)
    self.price_cents = (value.to_d * 100).round if value.present?
  end

  private

  def week_start_must_be_saturday
    return if week_start.blank?

    errors.add(:week_start, "doit être un samedi") unless week_start.saturday?
  end
end
