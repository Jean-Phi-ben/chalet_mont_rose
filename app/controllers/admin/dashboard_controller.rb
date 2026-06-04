class Admin::DashboardController < Admin::BaseController
  def index
    @weekly_rates_count = WeeklyRate.count
  end
end
