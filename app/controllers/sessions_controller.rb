class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to login_path, alert: "Trop de tentatives, réessayez plus tard." }

  # La page de connexion email/mot de passe est servie par /connexion
  # (formulaire + bouton Google). On y renvoie tout accès direct à /session/new.
  def new
    redirect_to login_path
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to login_path, alert: "Adresse email ou mot de passe incorrect."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other, notice: "Vous êtes déconnecté."
  end
end
