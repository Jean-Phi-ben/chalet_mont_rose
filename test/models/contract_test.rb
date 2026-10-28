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

  test "generate_otp! counts sends, keeps the attempts counter, and locks after OTP_MAX_SENDS" do
    @contract.update_columns(otp_attempts: 3)
    @contract.generate_otp!
    assert_equal 3, @contract.otp_attempts, "un renvoi ne rouvre pas les essais"
    assert_equal 1, @contract.otp_sends_count

    (Contract::OTP_MAX_SENDS - 1).times { @contract.generate_otp! }
    assert @contract.otp_locked?

    @contract.unlock_otp!
    assert_not @contract.otp_locked?
    assert_equal [ 0, 0, nil ], [ @contract.otp_attempts, @contract.otp_sends_count, @contract.otp_digest ]
  end

  test "compute_document_hash is stable and changes with content" do
    txt = ContractTemplate.canonical_text(@booking, @contract)
    h1 = @contract.compute_document_hash(txt)
    h2 = @contract.compute_document_hash(txt)
    assert_equal h1, h2, "même input → même hash"
    h3 = @contract.compute_document_hash(txt + " modifié")
    refute_equal h1, h3, "texte différent → hash différent"
  end

  test "contract_text : texte courant avant signature, texte gelé après" do
    assert_equal ContractTemplate.canonical_text(@booking, @contract), @contract.contract_text

    @contract.update_columns(canonical_text: "TEXTE GELÉ", status: Contract.statuses[:signed])
    assert_equal "TEXTE GELÉ", @contract.reload.contract_text
  end

  test "integrity_ok? : vrai si le texte gelé reproduit le hash, faux sinon" do
    text = ContractTemplate.canonical_text(@booking, @contract)
    @contract.update_columns(status: Contract.statuses[:signed], signed_at: Time.current,
                             signed_ip: "1.2.3.4", signed_user_agent: "UA", canonical_text: text)
    @contract.update_columns(document_hash: @contract.compute_document_hash(text))
    assert @contract.reload.integrity_ok?

    @contract.update_columns(canonical_text: text + " altéré")
    assert_not @contract.reload.integrity_ok?

    @contract.update_columns(canonical_text: nil)
    assert_not @contract.reload.integrity_ok?, "sans texte gelé, l'intégrité n'est pas vérifiable"
  end

  test "document hash does not depend on the application time zone" do
    text = ContractTemplate.canonical_text(@booking, @contract)
    @contract.update_columns(signed_at: Time.utc(2026, 10, 17, 7, 4, 0), signed_ip: "1.2.3.4", signed_user_agent: "UA")
    in_paris = Time.use_zone("Europe/Paris") { @contract.reload.compute_document_hash(text) }
    in_utc   = Time.use_zone("UTC")          { @contract.reload.compute_document_hash(text) }
    assert_equal in_utc, in_paris
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
