# Tableau de bord admin (pas de modèle : `authorize :dashboard`).
class DashboardPolicy < ApplicationPolicy
  def index? = admin?
end
