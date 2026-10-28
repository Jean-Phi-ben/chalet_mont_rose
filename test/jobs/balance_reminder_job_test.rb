require "test_helper"

class BalanceReminderJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActionMailer::TestHelper

  setup do
    travel_to Date.new(2026, 5, 22)
    @booking = Booking.create!(
      check_in: Date.new(2026, 6, 6), check_out: Date.new(2026, 6, 13),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 200_000, deposit_cents: 60_000,
      status: :confirmed
    )
    GenerateInvoiceJob.perform_now(@booking)
  end

  teardown { travel_back }

  test "sends a reminder for bookings checking in within the next BALANCE_REMINDER_DAYS days" do
    # check_in = 2026-06-06 → premier envoi possible le 2026-05-27 (J-10).
    travel_to Date.new(2026, 5, 27)
    assert_emails 1 do
      BalanceReminderJob.perform_now
    end
    assert_not_nil @booking.balance_invoice.reload.balance_reminder_sent_at
  end

  test "does not send before the J-10 window opens" do
    travel_to Date.new(2026, 5, 26)
    assert_no_emails { BalanceReminderJob.perform_now }
  end

  test "catches up a reminder that was missed (job not run on J-10, or late confirmation)" do
    travel_to Date.new(2026, 6, 2) # J-4 : la fenêtre J-10 est passée sans envoi
    assert_emails 1 do
      BalanceReminderJob.perform_now
    end
    mail = ActionMailer::Base.deliveries.last
    assert_match "3 juin 2026", mail.html_part.body.decoded, "échéance J-3 affichée"
  end

  test "an error on one booking does not block the others" do
    other = Booking.create!(
      check_in: Date.new(2026, 5, 30), check_out: Date.new(2026, 6, 6),
      first_name: "Paul", last_name: "Okay", email: "paul@example.com",
      total_price_cents: 100_000, deposit_cents: 30_000, status: :confirmed
    )
    GenerateInvoiceJob.perform_now(other)
    # Email invalide → le mailer lève pour cette réservation uniquement.
    @booking.update_columns(email: "")
    travel_to Date.new(2026, 5, 27)
    assert_emails 1 do
      BalanceReminderJob.perform_now
    end
    assert_not_nil other.balance_invoice.reload.balance_reminder_sent_at
  end

  test "does not send if the balance has already been received" do
    travel_to Date.new(2026, 5, 27)
    @booking.balance_invoice.update!(status: :received, received_on: Date.current)
    assert_no_emails do
      BalanceReminderJob.perform_now
    end
  end

  test "does not send a second time once balance_reminder_sent_at is set" do
    travel_to Date.new(2026, 5, 27)
    @booking.balance_invoice.update!(balance_reminder_sent_at: 1.hour.ago)
    assert_no_emails do
      BalanceReminderJob.perform_now
    end
  end

  test "ignores bookings that are not confirmed" do
    travel_to Date.new(2026, 5, 27)
    @booking.update_columns(status: Booking.statuses[:pending])
    assert_no_emails do
      BalanceReminderJob.perform_now
    end
  end

  test "accepts an explicit target_date" do
    assert_emails 1 do
      BalanceReminderJob.perform_now(target_date: Date.new(2026, 6, 6))
    end
  end
end
