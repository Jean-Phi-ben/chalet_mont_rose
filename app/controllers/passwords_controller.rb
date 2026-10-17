class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_password_path, alert: "Trop de demandes, réessayez dans quelques minutes." }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      UserMailer.reset(user).deliver_later
    end

    redirect_to login_path, notice: "Si un compte existe pour cette adresse, un email de réinitialisation vient de lui être envoyé."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.verify! # réinitialiser depuis la boîte email prouve l'adresse
      @user.sessions.destroy_all
      redirect_to login_path, notice: "Votre mot de passe a été modifié. Vous pouvez vous connecter."
    else
      redirect_to edit_password_path(params[:token]), alert: @user.errors.full_messages.to_sentence
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Ce lien de réinitialisation est invalide ou a expiré."
    end
end
