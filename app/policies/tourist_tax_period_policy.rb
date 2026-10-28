class TouristTaxPeriodPolicy < ApplicationPolicy
  def update? = admin?
end
