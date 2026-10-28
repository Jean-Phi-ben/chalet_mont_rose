require "test_helper"

class PurgeOldDataJobTest < ActiveJob::TestCase
  def booking(status:, updated: 4.years.ago, first_name: "Old")
    b = Booking.create!(check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 10), first_name: first_name, last_name: "X",
                        email: "#{first_name.downcase}@example.com", total_price_cents: 1_000, deposit_cents: 300)
    b.update_columns(status: Booking.statuses[status], updated_at: updated)
    b
  end

  test "purges only old, never-invoiced, non-confirmed requests and old email logs" do
    stale_pending  = booking(status: :pending)
    stale_rejected = booking(status: :rejected, first_name: "Rej")
    recent_pending = booking(status: :pending, updated: 1.month.ago, first_name: "New")
    old_confirmed  = booking(status: :confirmed, first_name: "Conf")
    invoiced       = booking(status: :cancelled, first_name: "Inv")
    invoiced.invoices.create!(kind: :deposit, amount_cents: 300)

    old_log = EmailLog.create!(mailer: "BookingMailer", action: "acknowledgement_to_client", to_addresses: "a@example.com",
                               subject: "s", message_id: "old-#{SecureRandom.hex}", sent_at: 4.years.ago)
    new_log = EmailLog.create!(mailer: "BookingMailer", action: "acknowledgement_to_client", to_addresses: "a@example.com",
                               subject: "s", message_id: "new-#{SecureRandom.hex}", sent_at: 1.day.ago)

    result = PurgeOldDataJob.perform_now
    assert_equal({ bookings: 2, email_logs: 1 }, result)

    assert_not Booking.exists?(stale_pending.id)
    assert_not Booking.exists?(stale_rejected.id)
    assert Booking.exists?(recent_pending.id)
    assert Booking.exists?(old_confirmed.id), "une réservation confirmée n'est jamais purgée"
    assert Booking.exists?(invoiced.id), "une réservation facturée n'est jamais purgée"
    assert_not EmailLog.exists?(old_log.id)
    assert EmailLog.exists?(new_log.id)
  end
end
