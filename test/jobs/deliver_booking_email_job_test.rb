require "test_helper"

class DeliverBookingEmailJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "delivers the mailer action and records an EmailLog" do
    booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 10),
      first_name: "Jean", last_name: "Dupont", email: "jean@example.com",
      total_price_cents: 100_000, deposit_cents: 30_000
    )
    assert_emails 1 do
      DeliverBookingEmailJob.perform_now(:acknowledgement_to_client, booking)
    end
    assert EmailLog.exists?(booking_id: booking.id, action: "acknowledgement_to_client")
  end
end
