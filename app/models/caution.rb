class Caution < ApplicationRecord
  belongs_to :booking
  validates :booking_id, uniqueness: true

  # pending   : créée en local, demande envoyée au provider
  # accepted  : le client a déposé sa caution (empreinte/pré-autorisation OK)
  # released  : caution libérée à la fin du séjour
  # captured  : caution capturée (débit effectif) suite à un sinistre
  # declined  : caution refusée par le client ou échec du provider
  enum :status, { pending: 0, accepted: 1, released: 2, captured: 3, declined: 4 }, prefix: true

  # Montant de la caution : CAUTION_AMOUNT (en euros) si défini, sinon 30 % du
  # séjour borné entre 500 et 2 000 €. Source unique (job, prestataire, contrat).
  FALLBACK_RATE      = 0.30
  FALLBACK_MIN_CENTS = 50_000
  FALLBACK_MAX_CENTS = 200_000

  def self.amount_for(booking)
    explicit = ENV["CAUTION_AMOUNT"].to_i
    return explicit * 100 if explicit.positive?

    (booking.total_price_cents.to_i * FALLBACK_RATE).round.clamp(FALLBACK_MIN_CENTS, FALLBACK_MAX_CENTS)
  end

  # Lien de dépôt utilisable par le client : demande en attente avec un vrai lien
  # (jamais un lien de test « about:blank » du mode stub).
  def depositable?
    status_pending? && deposit_url.to_s.start_with?("https://")
  end

  def amount_euros
    amount_cents.to_i / 100.0
  end
end
