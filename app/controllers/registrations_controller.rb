class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to signup_path, alert: "Trop de tentatives, réessayez plus tard." }

  def new
    return redirect_to(account_root_path) if authenticated?

    @user = User.new
  end

  # Crée le compte puis envoie le lien de vérification : l'espace client reste
  # vide tant que l'adresse n'est pas prouvée (sinon n'importe qui pourrait
  # s'inscrire avec l'email d'un client et voir ses réservations).
  def create
    @user = User.new(registration_params)

    # Les adresses administratrices ne s'inscrivent pas par mot de passe : un
    # inconnu ne doit pas pouvoir « réserver » un compte admin avant son titulaire.
    if AdminAccess.authorized?(@user.email_address)
      @user.errors.add(:email_address, "est réservée : connectez-vous avec Google ou avec votre mot de passe existant.")
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      return render :new, status: :unprocessable_entity
    end

    if @user.save
      UserMailer.verification(@user).deliver_later
      start_new_session_for(@user)
      redirect_to verification_pending_path, notice: "Votre compte est créé. Vérifiez votre boîte email pour activer votre espace."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
