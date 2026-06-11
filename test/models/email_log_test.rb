require "test_helper"

class EmailLogTest < ActiveSupport::TestCase
  test "label maps mailer/action to a human string" do
    log = EmailLog.new(mailer: "BookingMailer", action: "balance_reminder",
                       to_addresses: "x@y.com", sent_at: Time.current)
    assert_equal "Rappel solde J-10 (facture solde + caution + livret)", log.label
  end

  test "label falls back to Mailer#action when unknown" do
    log = EmailLog.new(mailer: "WeirdMailer", action: "ping",
                       to_addresses: "x@y.com", sent_at: Time.current)
    assert_equal "WeirdMailer#ping", log.label
  end

  test "to_list parses the CSV addresses" do
    log = EmailLog.new(to_addresses: "a@x.com, b@y.com")
    assert_equal %w[a@x.com b@y.com], log.to_list
  end
end
