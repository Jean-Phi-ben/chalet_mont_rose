# Vérification de l'adresse email après inscription par mot de passe.
#   - pending : page « vérifiez votre boîte » (compte connecté, non vérifié)
#   - create  : renvoi du lien
#   - show    : clic sur le lien reçu → adresse vérifiée, session ouverte
class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 3, within: 10.minutes, only: :create,
             with: -> { redirect_to verification_pending_path, alert: "Trop de demandes : réessayez dans quelques minutes." }

  def pending
    redirect_to account_root_path if Current.user.verified?
  end

  def create
    UserMailer.verification(Current.user).deliver_later unless Current.user.verified?
    redirect_to verification_pending_path, notice: "Un nouveau lien de vérification vient de vous être envoyé."
  end

  def show
    user = User.find_by_token_for(:email_verification, params[:token])
    if user
      user.verify!
      start_new_session_for(user) unless authenticated? && Current.user == user
      redirect_to account_root_path, notice: "Votre adresse email est vérifiée. Bienvenue dans votre espace."
    else
      redirect_to login_path, alert: "Ce lien de vérification est invalide ou a expiré. Connectez-vous pour en recevoir un nouveau."
    end
  end
end
