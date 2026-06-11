require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 2, 7), check_out: Date.new(2026, 2, 14),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 150_000, deposit_cents: 45_000
    )
    @contract = Contract.create!(
      booking: @booking, status: :sent, sent_at: Time.current,
      signer_first_name: "Léa", signer_last_name: "Martin",
      signer_email: "lea@example.com", signer_phone: "+33600000000",
      signer_address: "12 rue Alpine, 74170 Saint-Gervais"
    )
  end

  test "has_secure_token generates a token at create" do
    assert_equal 32, @contract.token.size
  end

  test "one contract per booking" do
    dup = Contract.new(booking: @booking)
    assert_not dup.save
  end

  test "generate_otp! returns a 6-digit code and stores a bcrypt digest" do
    code = @contract.generate_otp!
    assert_match(/\A\d{6}\z/, code)
    assert @contract.otp_digest.present?
    refute_equal code, @contract.otp_digest, "le code clair ne doit pas être stocké tel quel"
    assert @contract.otp_valid?(code)
  end

  test "otp_valid? returns false for a wrong code" do
    @contract.generate_otp!
    assert_not @contract.otp_valid?("000000")
  end

  test "otp expires after OTP_TTL" do
    code = @contract.generate_otp!
    assert @contract.otp_valid?(code)
    @contract.update_columns(otp_sent_at: 20.minutes.ago)
    assert_not @contract.otp_valid?(code)
    assert @contract.otp_expired?
  end

  test "otp_locked? after OTP_MAX_ATTEMPTS" do
    @contract.update_columns(otp_attempts: Contract::OTP_MAX_ATTEMPTS)
    assert @contract.otp_locked?
  end

  test "compute_document_hash is stable and changes with content" do
    txt = ContractTemplate.canonical_text(@booking, @contract)
    h1 = @contract.compute_document_hash(txt)
    h2 = @contract.compute_document_hash(txt)
    assert_equal h1, h2, "même input → même hash"
    h3 = @contract.compute_document_hash(txt + " modifié")
    refute_equal h1, h3, "texte différent → hash différent"
  end

  test "freezing : cannot modify a signed contract" do
    @contract.update!(
      status: :signed, signed_at: Time.current,
      signed_ip: "1.2.3.4", signature_image: "data:image/png;base64,xxx",
      document_hash: "abc"
    )
    @contract.signer_first_name = "Mallory"
    assert_not @contract.save
    assert_match(/Document signé/, @contract.errors.full_messages.first)
  end

  test "freezing allows attaching the signed PDF after signature" do
    @contract.update!(
      status: :signed, signed_at: Time.current,
      signed_ip: "1.2.3.4", signature_image: "data:image/png;base64,xxx",
      document_hash: "abc"
    )
    assert_nothing_raised do
      @contract.signed_pdf.attach(io: StringIO.new("PDF"), filename: "c.pdf", content_type: "application/pdf")
    end
  end
end
