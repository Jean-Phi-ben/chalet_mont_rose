class BookingPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin? && record.is_a?(Booking) && !record.amounts_locked?
  def update?  = admin? && record.is_a?(Booking) && !record.amounts_locked?
  # Seule une demande en attente se confirme (pas de reconfirmation d'une refusée/annulée).
  def confirm?           = admin? && record.is_a?(Booking) && record.pending?
  def reject?            = admin? && record.is_a?(Booking) && record.pending?
  def cancel?            = admin? && record.is_a?(Booking) && record.confirmed?
  def send_balance_reminder? = admin? && record.is_a?(Booking) && record.confirmed?
  # Déblocage de la signature verrouillée (trop d'essais / d'envois de code).
  def unlock_contract?    = admin? && record.is_a?(Booking) && record.contract&.status_sent? && record.contract.otp_locked?
  # Jamais une réservation confirmée, facturée ou au contrat signé.
  def destroy?           = admin? && record.is_a?(Booking) && !record.confirmed? && record.deletable?
  def archive_invoicing? = admin? && record.is_a?(Booking) && !record.invoicing_archived? && record.balance_invoice&.payment_received?
end
