require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # Dates de test en janvier 2026 : on se place avant pour qu'elles soient réservables.
  setup { travel_to Date.new(2025, 12, 15) }
  teardown { travel_back }

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
      email: "jean@example.com", guests_count: 4, terms_accepted: "1"
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
    assert_not_nil booking.terms_accepted_at
    assert_equal Booking::TERMS_VERSION, booking.terms_version
    assert_redirected_to reservation_path(booking.token)
  end

  test "create refuses a request without accepting the terms, keeping the input in the reopened modal" do
    assert_no_difference "Booking.count" do
      post reservations_url, params: { booking: booking_params(terms_accepted: "0", message: "Avec un chien") }
    end
    assert_response :unprocessable_entity
    assert_select "body[data-modal-open-value=true]"
    assert_select "[data-reservation-error]", text: /Conditions générales/
    assert_select "#reservation-modal input[name='booking[first_name]'][value=Jean]"
    assert_select "#reservation-modal textarea[name='booking[message]']", text: "Avec un chien"
    assert_select "#reservation-modal input[name='booking[check_in]'][value='2026-01-03']"
  end

  test "create ignores robots that fill the honeypot" do
    assert_no_difference "Booking.count" do
      post reservations_url, params: { booking: booking_params, website: "http://spam.example" }
    end
    assert_response :see_other
  end

  test "create is rate limited per IP" do
    5.times { post reservations_url, params: { booking: booking_params(email: "r#{_1}@example.com") } }
    assert_no_difference "Booking.count" do
      post reservations_url, params: { booking: booking_params }
    end
    assert_match "Trop de demandes", flash[:alert]
  end

  test "create enqueues the owner notification and the client acknowledgement" do
    assert_enqueued_jobs 2, only: DeliverBookingEmailJob do
      post reservations_url, params: { booking: booking_params }
    end
    assert_emails 2 do
      perform_enqueued_jobs(only: DeliverBookingEmailJob)
    end
    assert_equal 2, EmailLog.where(booking: Booking.last).count, "chaque envoi est journalisé"
  end

  test "create rejects a period without rates and persists nothing" do
    assert_no_difference "Booking.count" do
      post reservations_url, params: {
        booking: booking_params(check_in: Date.new(2026, 2, 7), check_out: Date.new(2026, 2, 14))
      }
    end
    assert_response :unprocessable_entity
    assert_select "[data-reservation-error]", text: /ne sont pas ouvertes/
  end

  test "create rejects a week that has already started" do
    travel_to Date.new(2026, 1, 5) # lundi : la semaine du samedi 3 a commencé
    assert_no_difference "Booking.count" do
      post reservations_url, params: { booking: booking_params }
    end
    assert_response :unprocessable_entity
    assert_select "[data-reservation-error]", text: /déjà commencé/
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
