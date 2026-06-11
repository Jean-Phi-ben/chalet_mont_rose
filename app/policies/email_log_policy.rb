class EmailLogPolicy < ApplicationPolicy
  def index? = admin?
  def show?  = admin?

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
