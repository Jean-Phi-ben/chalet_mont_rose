class BookingSettingPolicy < ApplicationPolicy
  def show?   = admin?
  def update? = admin?

  private

  def admin?
    user&.admin?
  end
end
