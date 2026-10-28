# Une facture est associée à une réservation et représente soit les arrhes (`deposit`),
# soit le solde (`balance`). Chaque réservation a donc deux factures avec deux numéros distincts.
#
# Règle d'immutabilité : une facture payée (ou dont la facturation est archivée) ne
# change plus, ni de montant ni de PDF (cf. #locked? et GenerateInvoiceJob).
class Invoice < ApplicationRecord
  belongs_to :booking
  has_one_attached :pdf

  enum :kind,   { deposit: 0, balance: 1 }, prefix: :kind
  enum :status, { awaiting: 0, received: 1 }, prefix: :payment

  # Délais de règlement (repris sur le PDF, dans les emails et l'espace client).
  DEPOSIT_DUE_DAYS       = 7   # arrhes à régler dans les 7 jours suivant l'émission
  BALANCE_DUE_DAYS       = 3   # solde dû au plus tard 3 jours avant l'arrivée
  BALANCE_REMINDER_DAYS  = 10  # rappel de solde (facture + caution + livret) envoyé 10 jours avant l'arrivée

  validates :number,       presence: true, uniqueness: true
  validates :issued_on,    presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kind,         uniqueness: { scope: :booking_id }
  validate  :amount_frozen_once_paid, on: :update

  before_validation :assign_issued_on, on: :create
  before_validation :assign_number,    on: :create
  # Une facture payée a toujours une date de paiement (ex. statut changé depuis l'admin sans date).
  before_save -> { self.received_on ||= Date.current }, if: :payment_received?

  scope :ordered, -> { order(:kind, :id) }

  # Construit (sans sauvegarder) les deux factures pour une réservation.
  def self.from_booking(booking)
    [
      new(booking: booking, kind: :deposit, amount_cents: booking.deposit_cents),
      new(booking: booking, kind: :balance, amount_cents: balance_amount_for(booking))
    ]
  end

  # Solde = total du séjour − arrhes facturées, quel que soit l'état de leur paiement :
  # une facture d'arrhes émise est due, le solde ne la réclame pas une seconde fois.
  def self.balance_amount_for(booking)
    deposit_cents = booking.deposit_invoice&.amount_cents || booking.deposit_cents
    booking.total_price_cents.to_i - deposit_cents.to_i
  end

  def label
    kind_deposit? ? "Arrhes" : "Solde"
  end

  # Date limite de règlement : arrhes à J+7 de l'émission, solde à J-3 de l'arrivée.
  def due_on
    kind_deposit? ? issued_on + DEPOSIT_DUE_DAYS : booking.check_in - BALANCE_DUE_DAYS
  end

  def overdue?(today = Date.current)
    payment_awaiting? && due_on < today
  end

  # Facture figée : payée, ou facturation de la réservation archivée.
  def locked?
    payment_received? || booking.invoicing_archived?
  end

  def mark_received!(on: Date.current)
    update!(status: :received, received_on: on)
  end

  def mark_awaiting!
    update!(status: :awaiting, received_on: nil)
  end

  private

  def amount_frozen_once_paid
    return unless amount_cents_changed? && status_was == "received"

    errors.add(:amount_cents, "ne peut plus être modifié : facture déjà payée")
  end

  def assign_issued_on
    self.issued_on ||= Date.current
  end

  def assign_number
    return if number.present?

    year = issued_on.year
    last = self.class.where("number LIKE ?", "CMR-#{year}-%").order(number: :desc).first
    seq  = last ? last.number.split("-").last.to_i + 1 : 1
    self.number = format("CMR-%d-%04d", year, seq)
  end
end
