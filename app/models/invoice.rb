# Une facture est associée à une réservation et représente soit les arrhes (`deposit`),
# soit le solde (`balance`). Chaque réservation a donc deux factures avec deux numéros distincts.
class Invoice < ApplicationRecord
  belongs_to :booking
  has_one_attached :pdf

  enum :kind,   { deposit: 0, balance: 1 }, prefix: :kind
  enum :status, { awaiting: 0, received: 1 }, prefix: :payment

  validates :number,       presence: true, uniqueness: true
  validates :issued_on,    presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kind,         uniqueness: { scope: :booking_id }

  before_validation :assign_issued_on, on: :create
  before_validation :assign_number,    on: :create

  # Si le statut de la facture d'arrhes change, on resynchronise le montant du solde.
  after_save_commit :resync_balance_amount, if: -> { kind_deposit? && saved_change_to_status? }

  scope :awaiting, -> { where(status: :awaiting) }
  scope :ordered,  -> { order(:kind, :id) }

  # Construit (sans sauvegarder) les deux factures pour une réservation.
  # Le montant du solde est calculé selon l'état actuel du paiement des arrhes :
  # arrhes non reçues → solde = total ; arrhes reçues → solde = total − arrhes.
  def self.from_booking(booking)
    [
      new(booking: booking, kind: :deposit, amount_cents: booking.deposit_cents),
      new(booking: booking, kind: :balance, amount_cents: balance_amount_for(booking))
    ]
  end

  # Solde dû en fonction de l'état des arrhes (utilisé à la création et lors des sync).
  def self.balance_amount_for(booking)
    deposit = booking.invoices.find_by(kind: :deposit)
    deposit_paid = deposit&.payment_received? ? deposit.amount_cents.to_i : 0
    booking.total_price_cents.to_i - deposit_paid
  end

  def label
    kind_deposit? ? "Arrhes" : "Solde"
  end

  def mark_received!(on: Date.current)
    update!(status: :received, received_on: on)
  end

  def mark_awaiting!
    update!(status: :awaiting, received_on: nil)
  end

  private

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

  def resync_balance_amount
    balance = booking.balance_invoice
    return unless balance

    new_amount = self.class.balance_amount_for(booking)
    return if balance.amount_cents.to_i == new_amount

    balance.update_columns(amount_cents: new_amount, updated_at: Time.current)
  end
end
