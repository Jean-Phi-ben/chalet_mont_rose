class Caution < ApplicationRecord
  belongs_to :booking
  validates :booking_id, uniqueness: true

  # pending   : créée en local, demande envoyée au provider
  # accepted  : le client a déposé sa caution (empreinte/pré-autorisation OK)
  # released  : caution libérée à la fin du séjour
  # captured  : caution capturée (débit effectif) suite à un sinistre
  # declined  : caution refusée par le client ou échec du provider
  enum :status, { pending: 0, accepted: 1, released: 2, captured: 3, declined: 4 }, prefix: true

  def depositable?
    status_pending? && deposit_url.present?
  end

  def amount_euros
    amount_cents.to_i / 100.0
  end
end
