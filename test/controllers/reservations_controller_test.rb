require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @check_in  = Date.new(2026, 1, 3)
    @check_out = Date.new(2026, 1, 17)
    WeeklyRate.create!(week_start: Date.new(2026, 1, 3),  price_cents: 100_000)
    WeeklyRate.create!(week_start: Date.new(2026, 1, 10), price_cents: 120_000)
  end

  def booking_params(overrides = {})
    {
      check_in: @check_in, check_out: @check_out,
      first_name: "Jean", last_name: "Dupont",
      email: "jean@example.com", guests_count: 4
    }.merge(overrides)
  end

  test "create persists a pending booking with the full breakdown" do
    assert_difference "Booking.count", 1 do
      post reservations_url, params: { booking: booking_params }
    end

    booking = Booking.last
    assert booking.pending?
    assert_equal 220_000, booking.accommodation_cents
    assert_equal 80_000, booking.cleaning_fee_cents       # 40 000 × 2 sem.
    assert_equal 14_560, booking.tourist_tax_cents        # 260 × 4 voy. × 14 nuits
    assert_equal 314_560, booking.total_price_cents
    assert_equal 66_000, booking.deposit_cents            # 30 % de l'hébergement
    assert_redirected_to reservation_path(booking.token)
  end

  test "create notifies the owner and acknowledges the client" do
    assert_enqueued_emails 2 do
      post reservations_url, params: { booking: booking_params }
    end
  end

  test "create rejects a period without rates and persists nothing" do
    assert_no_difference "Booking.count" do
      post reservations_url, params: {
        booking: booking_params(check_in: Date.new(2026, 2, 7), check_out: Date.new(2026, 2, 14))
      }
    end
    assert_redirected_to calendar_path
  end

  test "show finds a booking by token" do
    booking = Booking.create!(booking_params.merge(total_price_cents: 220_000, deposit_cents: 66_000))
    get reservation_url(booking.token)
    assert_response :success
    assert_includes response.body, "Suivi de votre demande"
  end

  test "show returns not found for an unknown token" do
    get reservation_url("does-not-exist")
    assert_response :not_found
  end
end
