require "test_helper"

class BalanceReminderMailerTest < ActionMailer::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
      first_name: "Inès", last_name: "Robert", email: "ines@example.com",
      total_price_cents: 200_000, deposit_cents: 60_000,
      status: :confirmed
    )
    GenerateInvoiceJob.perform_now(@booking)
  end

  test "sends to the client and CCs the admin owner" do
    ENV["MAILER_OWNER_EMAIL"] = "owner@chaletmontrose.fr"
    mail = BookingMailer.balance_reminder(@booking)
    assert_equal ["ines@example.com"], mail.to
    assert_equal ["owner@chaletmontrose.fr"], mail.cc
    assert_match(/solde/i, mail.subject)
    body = mail.html_part.body.decoded
    assert_match "solde de", body
  ensure
    ENV.delete("MAILER_OWNER_EMAIL")
  end

  test "includes the caution deposit link when a depositable caution exists" do
    CreateCautionJob.perform_now(@booking)   # crée une Caution :pending avec deposit_url
    mail = BookingMailer.balance_reminder(@booking)
    html = mail.html_part.body.decoded
    assert_match "Déposer la caution", html
    assert_match @booking.caution.deposit_url, mail.text_part.body.decoded
  end

  test "attaches the balance invoice + every Document with a file" do
    Document.create!(kind: :cgu, title: "CGU 2026") do |d|
      d.file.attach(io: StringIO.new("%PDF-1.4 cgu"), filename: "cgu.pdf", content_type: "application/pdf")
    end
    Document.create!(kind: :livret, title: "Livret") do |d|
      d.file.attach(io: StringIO.new("%PDF-1.4 livret"), filename: "livret.pdf", content_type: "application/pdf")
    end

    mail = BookingMailer.balance_reminder(@booking)
    filenames = mail.attachments.map(&:filename)
    assert_includes filenames, "cgu.pdf"
    assert_includes filenames, "livret.pdf"
    assert(filenames.any? { |f| f.start_with?("facture-solde-") })
  end
end
