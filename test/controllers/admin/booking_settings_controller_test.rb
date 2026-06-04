require "test_helper"

class Admin::BookingSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email_address: "admin@example.com", password: "password", admin: true)
    sign_in_as(@admin)
  end

  test "show renders the current settings with their defaults" do
    get admin_booking_setting_url
    assert_response :success
    assert_select "input[name='booking_setting[cleaning_fee_euros]'][value='400.0']"
  end

  test "update persists new fee values" do
    patch admin_booking_setting_url,
          params: { booking_setting: { cleaning_fee_euros: 450, tourist_tax_per_person_per_night_euros: 3.10 } }
    assert_redirected_to admin_booking_setting_path
    setting = BookingSetting.current
    assert_equal 45_000, setting.cleaning_fee_cents
    assert_equal 310, setting.tourist_tax_per_person_per_night_cents
  end

  test "show renders the tourist tax periods block" do
    get admin_booking_setting_url
    assert_response :success
    assert_match "Taxe de séjour à reverser", response.body
    # Mention de la fenêtre d'alerte (avant l'implémentation des notifications Telegram).
    assert_match "1 → 15 mai", response.body
    assert_match "1 → 15 octobre", response.body
  end
end
