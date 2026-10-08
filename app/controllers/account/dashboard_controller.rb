class Account::DashboardController < Account::BaseController
  def index
    @bookings = my_bookings.includes(:contract, :invoices).order(check_in: :desc)
  end
end
