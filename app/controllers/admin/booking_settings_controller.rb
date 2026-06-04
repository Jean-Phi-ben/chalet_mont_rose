class Admin::BookingSettingsController < Admin::BaseController
  def show
    @setting = BookingSetting.current
    authorize @setting
    @tax_periods = TouristTaxPeriod.completed_periods
  end

  def update
    @setting = BookingSetting.current
    authorize @setting
    if @setting.update(setting_params)
      redirect_to admin_booking_setting_path, notice: "Paramètres tarifaires mis à jour."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:booking_setting).permit(:cleaning_fee_euros, :tourist_tax_per_person_per_night_euros)
  end
end
