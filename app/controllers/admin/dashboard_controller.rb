class Admin::DashboardController < Admin::BaseController
  def index
    @weekly_rates_count = WeeklyRate.count
    @notes = Note.active.sorted
    @note  = Note.new
  end
end
