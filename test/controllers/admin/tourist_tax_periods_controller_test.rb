require "test_helper"

class Admin::TouristTaxPeriodsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email_address: "admin@example.com", password: "password", admin: true)
    sign_in_as(@admin)
  end

  test "update creates a period and marks it paid" do
    assert_difference "TouristTaxPeriod.count", 1 do
      patch admin_tourist_tax_periods_url, params: { season: "summer", year: 2025, paid: "1" }
    end
    period = TouristTaxPeriod.find_by(season: "summer", year: 2025)
    assert period.paid?
    assert_equal Date.current, period.paid_on
    assert_redirected_to admin_booking_setting_path
  end

  test "update flips an existing period back to unpaid" do
    TouristTaxPeriod.create!(season: "summer", year: 2025, paid: true, paid_on: Date.current)
    patch admin_tourist_tax_periods_url, params: { season: "summer", year: 2025 }
    period = TouristTaxPeriod.find_by(season: "summer", year: 2025)
    refute period.paid?
    assert_nil period.paid_on
  end
end
