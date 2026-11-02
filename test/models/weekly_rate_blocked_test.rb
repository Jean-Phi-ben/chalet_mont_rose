require "test_helper"

class WeeklyRateBlockedTest < ActiveSupport::TestCase
  setup do
    @week = Date.new(2026, 7, 4) # samedi
    @rate = WeeklyRate.create!(week_start: @week, price_cents: 300_000)
    WeeklyRate.create!(week_start: @week + 7, price_cents: 300_000)
  end

  test "a family week is occupied on the calendar like a confirmed booking (nights + transitions)" do
    @rate.update!(blocked: true)
    nights = Booking.blocked_dates_between(@week - 7, @week + 14)
    assert_includes nights, @week + 1
    assert_includes nights, @week + 6
    assert_not_includes nights, @week, "le samedi d'arrivée est un jour de transition"
    assert_not_includes nights, @week + 7
    transitions = Booking.transition_dates_between(@week - 7, @week + 14)
    assert_includes transitions, @week
    assert_includes transitions, @week + 7
  end

  test "the quote refuses a family week, the next week stays bookable" do
    @rate.update!(blocked: true)
    assert_equal "semaine_indisponible", Pricing.quote(@week, @week + 7)[:reason]
    assert Pricing.quote(@week + 7, @week + 14)[:bookable]
    assert_equal "semaine_indisponible", Pricing.quote(@week, @week + 14)[:reason], "séjour à cheval refusé"
  end

  test "a booking cannot be confirmed over a family week, and a booked week cannot be blocked" do
    @rate.update!(blocked: true)
    booking = Booking.new(check_in: @week, check_out: @week + 7, first_name: "A", last_name: "B", email: "a@example.com",
                          total_price_cents: 1, deposit_cents: 0, status: :confirmed)
    assert_not booking.valid?
    assert_match "réservée par la famille", booking.errors.full_messages.to_sentence

    @rate.update!(blocked: false)
    booking.save!
    assert_not @rate.update(blocked: true)
    assert_match "réservation confirmée", @rate.errors.full_messages.to_sentence
  end

  test "a family week is not advertised as the cheapest bookable week" do
    @rate.update!(blocked: true, price_cents: 1_000)
    assert_equal 300_000, WeeklyRate.single_week_bookable.minimum(:price_cents)
  end
end
