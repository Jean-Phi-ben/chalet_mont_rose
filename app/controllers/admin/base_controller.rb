class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_admin

  private

  def require_admin
    return if Current.user&.admin?

    flash[:alert] = "Accès réservé à l'administrateur."
    redirect_to root_path
  end
end
