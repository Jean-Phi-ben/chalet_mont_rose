class Admin::BaseController < ApplicationController
  layout "admin"
  # On ne révèle pas l'existence du back-office : un visiteur anonyme ou non
  # administrateur reçoit un 404 standard (pas de redirection vers la connexion).
  skip_before_action :require_authentication
  before_action :require_admin
  # Garde-fou : chaque action admin doit passer par Pundit (`authorize`).
  after_action :verify_authorized

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def require_admin
    resume_session
    return if Current.user&.admin?

    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end

  def record_not_found
    flash[:alert] = "Cet enregistrement n'existe plus (peut-être supprimé)."
    redirect_to admin_root_path
  end
end
