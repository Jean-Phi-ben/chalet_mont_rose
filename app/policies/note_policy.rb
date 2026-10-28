class NotePolicy < ApplicationPolicy
  def index?     = admin?
  def create?    = admin?
  def update?    = admin?
  def destroy?   = admin?
  def toggle?    = admin?
  def archive?   = admin?
  def unarchive? = admin?
  def archived?  = admin?
end
