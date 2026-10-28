class BookingSettingPolicy < ApplicationPolicy
  def show?   = admin?
  def update? = admin?
end
