# Paramètres tarifaires globaux applicables aux futures réservations.
# Stockés en centimes ; les `*_euros` sont des accesseurs pour les formulaires admin.
# Pattern singleton : `BookingSetting.current` renvoie l'unique ligne (créée si absente).
class BookingSetting < ApplicationRecord
  validates :cleaning_fee_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :tourist_tax_per_person_per_night_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :vat_rate_percent, numericality: { greater_than_or_equal_to: 0, less_than: 100 }

  def self.current
    first || create!
  end

  def cleaning_fee_euros
    cleaning_fee_cents && cleaning_fee_cents / 100.0
  end

  def cleaning_fee_euros=(value)
    self.cleaning_fee_cents = (value.to_d * 100).round if value.present?
  end

  def tourist_tax_per_person_per_night_euros
    tourist_tax_per_person_per_night_cents && tourist_tax_per_person_per_night_cents / 100.0
  end

  def tourist_tax_per_person_per_night_euros=(value)
    self.tourist_tax_per_person_per_night_cents = (value.to_d * 100).round if value.present?
  end
end
