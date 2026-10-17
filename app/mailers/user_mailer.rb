# Emails liés au compte client (hors réservation) : réinitialisation du mot de
# passe et vérification de l'adresse.
class UserMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Réinitialisation de votre mot de passe — Chalet Mont Rose", to: user.email_address
  end

  def verification(user)
    @user = user
    @url  = email_verification_url(user.generate_token_for(:email_verification))
    mail subject: "Vérifiez votre adresse email — Chalet Mont Rose", to: user.email_address
  end
end
