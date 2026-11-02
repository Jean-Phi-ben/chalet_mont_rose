class WeeklyRate < ApplicationRecord
  validates :week_start, presence: true, uniqueness: true
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :min_weeks, numericality: { greater_than_or_equal_to: 1 }
  validate :week_start_must_be_saturday
  validate :cannot_block_a_booked_week

  scope :ordered, -> { order(:week_start) }
  scope :upcoming, -> { where("week_start >= ?", Date.current.beginning_of_week(:saturday)) }
  # Tarifs réservables sur une seule semaine (min_weeks = 1) : les seuls qui peuvent
  # être annoncés « à partir de X € / semaine » sans induire en erreur.
  scope :single_week_bookable, -> { where("min_weeks <= ?", 1).where(blocked: false) }
  # Semaines réservées par la famille (occupées sans réservation ni facture).
  scope :blocked, -> { where(blocked: true) }

  # Semaines bloquées qui chevauchent [check_in, check_out) : la nuit du samedi
  # d'arrivée est la première occupée, celle du vendredi suivant la dernière.
  def self.blocked_overlap?(check_in, check_out)
    return false if check_in.nil? || check_out.nil?

    blocked.where("week_start < ? AND week_start + 7 > ?", check_out, check_in).exists?
  end

  # :past, :current (la semaine qui contient aujourd'hui) ou :upcoming.
  def period
    current = Date.current.beginning_of_week(:saturday)
    if week_start < current then :past
    elsif week_start == current then :current
    else :upcoming
    end
  end

  def week_end
    week_start + 7
  end

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

  # On ne bloque pas une semaine sur laquelle une réservation est confirmée.
  def cannot_block_a_booked_week
    return unless blocked && week_start && Booking.confirmed_overlap?(week_start, week_end)

    errors.add(:blocked, "impossible : une réservation confirmée occupe déjà cette semaine")
  end
end
