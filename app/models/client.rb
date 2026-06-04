class Client < ApplicationRecord
  has_many :bookings, dependent: :nullify

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: Booking::EMAIL_FORMAT }

  normalizes :email, with: ->(e) { e.to_s.downcase.strip }

  # Quand l'admin modifie la fiche client, on propage le changement sur les
  # snapshots des réservations associées (les bookings dupliquent first_name /
  # last_name / phone à la création — sans ce sync, l'ancienne valeur persisterait).
  after_update_commit :propagate_to_bookings

  def full_name
    "#{first_name} #{last_name}".strip
  end

  private

  def propagate_to_bookings
    attrs = {}
    attrs[:first_name] = first_name if saved_change_to_first_name?
    attrs[:last_name]  = last_name  if saved_change_to_last_name?
    attrs[:phone]      = phone      if saved_change_to_phone?
    return if attrs.empty?

    bookings.update_all(attrs.merge(updated_at: Time.current))
  end
end
