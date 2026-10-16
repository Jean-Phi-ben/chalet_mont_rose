class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Permet de gérer proprement les accès refusés
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :redirect_to_canonical_host

  # Seules les pages publiques (PagesController) sont indexables ; tout le reste
  # (connexion, espace client, suivi de réservation, admin) reçoit un noindex.
  helper_method :indexable?

  private

  def indexable?
    false
  end

  # Une seule adresse pour Google : http:// et chaletmontrose.fr sans www redirigent
  # en 301 vers https://www.chaletmontrose.fr. GET/HEAD seulement (un POST redirigé
  # perdrait son corps) ; les autres hôtes (localhost, staging par IP) ne sont pas touchés.
  def redirect_to_canonical_host
    return unless request.get? || request.head?
    return unless request.host.in?(SeoHelper::SITE_HOSTS)
    return if request.host == SeoHelper::SITE_HOST && request.ssl?

    redirect_to "https://#{SeoHelper::SITE_HOST}#{request.fullpath}",
                status: :moved_permanently, allow_other_host: true
  end

  # Pundit appelle `current_user` par défaut ; on utilise l'auth Rails 8 (Current.user).
  def pundit_user
    Current.user
  end

  def user_not_authorized
    flash[:alert] = "Vous n'avez pas l'autorisation d'accéder à cette page."
    redirect_back_or_to root_path
  end
end
