require "test_helper"

class BookingMailerTest < ActionMailer::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "client@example.com",
      guests_count: 4, total_price_cents: 220_000, deposit_cents: 66_000
    )
  end

  test "new_request_to_owner targets the owner and replies to the client" do
    with_env("MAILER_OWNER_EMAIL", "owner@example.com") do
      mail = BookingMailer.new_request_to_owner(@booking)
      assert_equal ["owner@example.com"], mail.to
      assert_equal ["client@example.com"], mail.reply_to
      assert_match "Jean Dupont", mail.subject
      assert_match "Jean Dupont", mail.body.encoded
    end
  end

  test "acknowledgement_to_client targets the client with a tracking link" do
    mail = BookingMailer.acknowledgement_to_client(@booking)
    assert_equal ["client@example.com"], mail.to
    assert_match "Chalet Mont Rose", mail.subject
    assert_match @booking.token, mail.body.encoded
  end

  test "rejected targets the client and references the period" do
    mail = BookingMailer.rejected(@booking)
    assert_equal ["client@example.com"], mail.to
    assert_match "Chalet Mont Rose", mail.subject
    assert_match "Jean", mail.body.encoded
  end

  private

  def with_env(key, value)
    original = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = original
  end
end
