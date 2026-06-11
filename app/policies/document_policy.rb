class DocumentPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def new?     = admin?
  def create?  = admin?
  def edit?    = admin?
  def update?  = admin?
  def destroy? = admin?

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
