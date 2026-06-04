class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Permet de gérer proprement les accès refusés
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Pundit appelle `current_user` par défaut ; on utilise l'auth Rails 8 (Current.user).
  def pundit_user
    Current.user
  end

  def user_not_authorized
    flash[:alert] = "Vous n'avez pas l'autorisation d'accéder à cette page."
    redirect_back_or_to root_path
  end
end
