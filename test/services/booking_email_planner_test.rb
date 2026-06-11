require "test_helper"

class BookingEmailPlannerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Date.new(2026, 5, 20)
    @booking = Booking.create!(
      check_in: Date.new(2026, 6, 6), check_out: Date.new(2026, 6, 13),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 200_000, deposit_cents: 60_000,
      status: :confirmed
    )
    GenerateInvoiceJob.perform_now(@booking)
  end

  teardown { travel_back }

  test "plans a J-10 reminder when the booking is confirmed and the balance is unpaid" do
    planned = BookingEmailPlanner.for(@booking)
    assert_equal 1, planned.size
    assert_match "Rappel solde J-10", planned.first.label
    assert_equal Date.new(2026, 5, 27), planned.first.scheduled_for
  end

  test "does not plan when balance is already received" do
    @booking.balance_invoice.update!(status: :received, received_on: Date.current)
    assert_empty BookingEmailPlanner.for(@booking)
  end

  test "does not plan when reminder is already sent" do
    @booking.balance_invoice.update!(balance_reminder_sent_at: 1.hour.ago)
    assert_empty BookingEmailPlanner.for(@booking)
  end

  test "does not plan for non-confirmed bookings" do
    @booking.update_columns(status: Booking.statuses[:pending])
    assert_empty BookingEmailPlanner.for(@booking)
  end

  test "marks the reminder as overdue when the scheduled date has passed (but still affichable)" do
    travel_to Date.new(2026, 6, 1)
    planned = BookingEmailPlanner.for(@booking)
    assert_equal 1, planned.size
    assert planned.first.overdue
  end

  test "does not plan when the stay has already started" do
    travel_to Date.new(2026, 6, 7)  # check_in était le 06/06
    assert_empty BookingEmailPlanner.for(@booking)
  end
end
