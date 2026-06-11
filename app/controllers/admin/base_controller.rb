class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_admin

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def require_admin
    return if Current.user&.admin?

    flash[:alert] = "Accès réservé à l'administrateur."
    redirect_to root_path
  end

  def record_not_found
    flash[:alert] = "Cet enregistrement n'existe plus (peut-être supprimé)."
    redirect_to admin_root_path
  end
end
