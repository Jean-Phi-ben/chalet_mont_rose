require "test_helper"

class SwiklyProviderTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 200_000, deposit_cents: 60_000
    )
  end

  # Bascule Rails.env (inquirer seulement, pas la config) le temps du bloc.
  def in_production
    original = Rails.env
    Rails.env = "production"
    yield
  ensure
    Rails.env = original
  end

  test "stub mode outside production gives a non-depositable link (never shown to a client)" do
    result = SwiklyProvider.create_request(@booking)
    assert result.provider_request_id.present?
    assert_not result.deposit_url.start_with?("https://")
    CreateCautionJob.perform_now(@booking)
    assert_not @booking.reload.caution.depositable?, "un lien de test n'est jamais « déposable »"
  end

  test "in production without credentials the provider raises instead of stubbing" do
    in_production do
      assert_raises(SwiklyProvider::Error) { SwiklyProvider.create_request(@booking) }
    end
  end

  test "in production, staging still stubs" do
    ENV["STAGING"] = "true"
    in_production do
      assert_nothing_raised { SwiklyProvider.create_request(@booking) }
    end
  ensure
    ENV.delete("STAGING")
  end

  test "sandbox only when explicitly requested in production, by default elsewhere" do
    ENV.delete("SWIKLY_TEST_MODE")
    assert SwiklyProvider.test_mode?
    in_production { assert_not SwiklyProvider.test_mode? }
    ENV["SWIKLY_TEST_MODE"] = "true"
    in_production { assert SwiklyProvider.test_mode? }
  ensure
    ENV.delete("SWIKLY_TEST_MODE")
  end

  test "the deposit hold extends CAUTION_HOLD_DAYS after check-out" do
    payload = SwiklyProvider.new.send(:payload_for, @booking)
    assert_equal "2026-07-18", payload[:deposit][:endDate] # 11 juillet + 7 jours
    ENV["CAUTION_HOLD_DAYS"] = "3"
    assert_equal "2026-07-14", SwiklyProvider.new.send(:payload_for, @booking)[:deposit][:endDate]
  ensure
    ENV.delete("CAUTION_HOLD_DAYS")
  end
end
