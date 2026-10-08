class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to signup_path, alert: "Trop de tentatives, réessayez plus tard." }

  def new
    return redirect_to(account_root_path) if authenticated?

    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.admin = false # un compte créé publiquement n'est jamais administrateur

    if @user.save
      start_new_session_for(@user)
      redirect_to after_authentication_url, notice: "Votre compte a bien été créé."
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
