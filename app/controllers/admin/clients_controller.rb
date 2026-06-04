class Admin::ClientsController < Admin::BaseController
  before_action :set_client, only: %i[show edit update]

  def show
    authorize @client
    @bookings = @client.bookings.order(check_in: :desc)
  end

  def edit
    authorize @client
  end

  def update
    authorize @client
    if @client.update(client_params)
      redirect_to admin_client_path(@client), notice: "Fiche client mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  # L'email du client est volontairement absent : c'est la clé d'identification,
  # il n'est pas modifiable depuis l'interface admin.
  def client_params
    params.require(:client).permit(:first_name, :last_name, :phone, :address)
  end
end
