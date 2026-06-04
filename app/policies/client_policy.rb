class ClientPolicy < ApplicationPolicy
  def show?   = admin?
  def edit?   = admin?
  def update? = admin?

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
