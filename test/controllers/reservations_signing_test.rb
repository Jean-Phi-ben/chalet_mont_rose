require "test_helper"

class ReservationsSigningTest < ActionDispatch::IntegrationTest
  # PNG factice de ~1 Ko (au-delà de SIGNATURE_MIN_BYTES = 500). Pas un PNG
  # valide bit à bit mais la validation ne fait que vérifier le préfixe et
  # la taille — le PDF gère gracieusement les images illisibles.
  FAKE_PNG_BIG  = "data:image/png;base64,#{Base64.strict_encode64('x' * 1000)}".freeze
  FAKE_PNG_TINY = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=".freeze

  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 5, 9), check_out: Date.new(2026, 5, 16),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      phone: "+33600000000", total_price_cents: 150_000, deposit_cents: 45_000
    )
    SendContractJob.perform_now(@booking)
    @contract = @booking.reload.contract
    ActionMailer::Base.deliveries.clear
  end

  test "GET /reservations/:token/contract renders the signing page when contract is sent" do
    get contract_reservation_url(@booking.token)
    assert_response :success
    assert_match "Contrat de location", response.body
    # Le signer figé apparaît bien
    assert_match "Léa", response.body
  end

  test "GET /reservations/:token/contract auto-sends an OTP on first visit" do
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      get contract_reservation_url(@booking.token)
    end
    assert @contract.reload.otp_digest.present?
  end

  test "GET /reservations/:token/contract does NOT re-send OTP if one is still valid" do
    @contract.generate_otp!
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      get contract_reservation_url(@booking.token)
    end
  end

  test "POST sign_contract rejects an OTP that is not 6 digits" do
    @contract.generate_otp!
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: "abc12", signature_image: FAKE_PNG_BIG, accepted: "1" }
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "POST sign_contract rejects a too-small signature image (empty canvas)" do
    code = @contract.generate_otp!
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: code, signature_image: FAKE_PNG_TINY, accepted: "1" }
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "successful signing also emails the signed PDF to the client" do
    code = @contract.generate_otp!
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      post sign_contract_reservation_url(@booking.token),
           params: { otp_code: code, signature_image: FAKE_PNG_BIG, accepted: "1" }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @booking.email ], mail.to
    assert_match "contrat signé", mail.subject.downcase
    # PDF attaché
    assert mail.attachments.any? { |a| a.filename.start_with?("contrat-signe-") }
  end

  test "POST request_otp generates a digest + sends an email with a 6-digit code" do
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      post request_otp_reservation_url(@booking.token)
    end
    @contract.reload
    assert @contract.otp_digest.present?
    assert_redirected_to contract_reservation_path(@booking.token)
  end

  test "POST sign_contract rejects without OTP" do
    post sign_contract_reservation_url(@booking.token),
         params: { signature_image: FAKE_PNG_BIG, accepted: "1" }
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "POST sign_contract rejects with wrong OTP and increments attempts" do
    @contract.generate_otp!
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: "000000", signature_image: FAKE_PNG_BIG, accepted: "1" }
    assert_response :unprocessable_entity
    assert_equal 1, @contract.reload.otp_attempts
    assert_not @contract.status_signed?
  end

  test "POST sign_contract with valid OTP signs the contract, freezes it, records proof and generates PDF" do
    code = @contract.generate_otp!
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: code, signature_image: FAKE_PNG_BIG, accepted: "1" }
    assert_redirected_to contract_reservation_path(@booking.token)
    @contract.reload
    assert @contract.status_signed?
    assert_not_nil @contract.signed_at
    assert @contract.signed_ip.present?
    assert @contract.document_hash.present?
    assert_equal 64, @contract.document_hash.length, "hash SHA-256 hex (64 chars)"
    # Digest OTP purgé après signature.
    assert_nil @contract.otp_digest
    # PDF généré.
    assert @contract.signed_pdf.attached?
  end

  test "POST sign_contract refuses if the checkbox isn't ticked" do
    code = @contract.generate_otp!
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: code, signature_image: FAKE_PNG_BIG, accepted: "0" }
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "signature_image must be a data URL image" do
    code = @contract.generate_otp!
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: code, signature_image: "not a data url", accepted: "1" }
    assert_response :unprocessable_entity
  end
end
