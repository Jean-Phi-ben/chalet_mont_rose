class TouristTaxPeriodPolicy < ApplicationPolicy
  def update? = admin?

  private

  def admin?
    user&.admin?
  end
end
