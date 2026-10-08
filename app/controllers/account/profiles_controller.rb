class Account::ProfilesController < Account::BaseController
  before_action :set_profile

  def edit; end

  def update
    if @client.update(profile_params)
      redirect_to account_profile_path, notice: "Profil mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # L'email est l'identité de connexion (Google) → non modifiable ici.
  def set_profile
    @client = my_client || Client.new(email: current_email)
  end

  def profile_params
    params.require(:client).permit(:first_name, :last_name, :phone, :address)
  end
end
