class InvoicePolicy < ApplicationPolicy
  def index?         = admin?
  def show?          = admin?
  def update?        = admin?
  def mark_received? = admin?
  def mark_awaiting? = admin?

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
