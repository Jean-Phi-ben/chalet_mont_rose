require "test_helper"

# EmailLog.record! est appelé explicitement après chaque envoi de mail
# (depuis BookingMailer.dispatch) — pas via observer. On vérifie ici qu'il
# crée bien une ligne avec les bonnes métadonnées et les pièces jointes.
class EmailLogRecordTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 9, 5), check_out: Date.new(2026, 9, 12),
      first_name: "Inès", last_name: "Robert", email: "ines@example.com",
      total_price_cents: 180_000, deposit_cents: 54_000
    )
  end

  test "record! persists a row + attachments from a Mail::Message" do
    mail = BookingMailer.acknowledgement_to_client(@booking).message
    mail.attachments["dummy.pdf"] = "%PDF-1.4 dummy"

    assert_difference("EmailLog.count", 1) do
      EmailLog.record!(mail, mailer: "BookingMailer", action: "acknowledgement_to_client", booking: @booking)
    end

    log = EmailLog.recent.first
    assert_equal "BookingMailer", log.mailer
    assert_equal "acknowledgement_to_client", log.action
    assert_equal "ines@example.com", log.to_addresses
    assert_equal @booking.id, log.booking_id
    assert log.attachments.attached?
    assert_equal "dummy.pdf", log.attachments.first.filename.to_s
  end

  test "record! is idempotent on message_id (no duplicate)" do
    delivery = BookingMailer.acknowledgement_to_client(@booking)
    delivery.deliver_now   # le message_id est généré au moment de la livraison
    mail = delivery.message
    assert mail.message_id.present?, "le message_id doit être généré après deliver_now"

    EmailLog.record!(mail, mailer: "BookingMailer", action: "acknowledgement_to_client", booking: @booking)

    assert_no_difference("EmailLog.count") do
      EmailLog.record!(mail, mailer: "BookingMailer", action: "acknowledgement_to_client", booking: @booking)
    end
  end

  test "BookingMailer.dispatch delivers AND creates an EmailLog" do
    assert_difference([ "ActionMailer::Base.deliveries.size", "EmailLog.count" ], 1) do
      BookingMailer.dispatch(:acknowledgement_to_client, @booking)
    end
    log = EmailLog.recent.first
    assert_equal "BookingMailer", log.mailer
    assert_equal "acknowledgement_to_client", log.action
    assert_equal @booking.id, log.booking_id
  end
end
