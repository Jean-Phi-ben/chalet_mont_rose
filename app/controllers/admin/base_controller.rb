class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_admin

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def require_admin
    return if Current.user&.admin?

    # On ne révèle pas l'existence du back-office : tout accès non autorisé
    # renvoie un 404 standard, comme si la page n'existait pas.
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end

  def record_not_found
    flash[:alert] = "Cet enregistrement n'existe plus (peut-être supprimé)."
    redirect_to admin_root_path
  end
end
