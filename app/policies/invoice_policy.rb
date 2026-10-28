class InvoicePolicy < ApplicationPolicy
  def index?         = admin?
  def show?          = admin?
  def update?        = admin?
  def mark_received? = admin?
  def mark_awaiting? = admin?
end
