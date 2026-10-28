class EmailLogPolicy < ApplicationPolicy
  def index? = admin?
  def show?  = admin?
end
