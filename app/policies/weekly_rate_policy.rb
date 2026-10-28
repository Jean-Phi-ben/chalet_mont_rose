class WeeklyRatePolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def new?     = admin?
  def update?  = admin?
  def edit?    = admin?
  def destroy? = admin?
end
