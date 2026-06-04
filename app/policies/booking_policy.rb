class BookingPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin? && record.is_a?(Booking) && !record.amounts_locked?
  def update?  = admin? && record.is_a?(Booking) && !record.amounts_locked?
  def confirm?           = admin? && record.is_a?(Booking) && !record.confirmed?
  def reject?            = admin? && record.is_a?(Booking) && record.pending?
  def cancel?            = admin? && record.is_a?(Booking) && record.confirmed?
  def destroy?           = admin?
  def archive_invoicing? = admin? && record.is_a?(Booking) && !record.invoicing_archived? && record.balance_invoice&.payment_received?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end

  private

  def admin?
    user&.admin?
  end
end
