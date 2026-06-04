class Admin::TouristTaxPeriodsController < Admin::BaseController
  def update
    period = TouristTaxPeriod.find_or_initialize_by(season: params[:season], year: params[:year].to_i)
    authorize period

    paid = params[:paid].present?
    period.paid    = paid
    period.paid_on = paid ? Date.current : nil
    period.save!

    redirect_to admin_booking_setting_path,
                notice: paid ? "Période marquée comme payée." : "Période repassée en attente."
  end
end
