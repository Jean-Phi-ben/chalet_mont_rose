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

  def sign!(code, image: FAKE_PNG_BIG, accepted: "1")
    post sign_contract_reservation_url(@booking.token),
         params: { otp_code: code, signature_image: image, accepted: accepted }
  end

  test "GET /reservations/:token/contract renders the signing page without any side effect" do
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      get contract_reservation_url(@booking.token)
    end
    assert_response :success
    assert_match "Contrat de location", response.body
    assert_match "Léa", response.body
    # Les 9 sections rendues sont celles du texte canonique (même source).
    assert_select "[data-contract-section]", 9
    assert_match "Version du contrat : #{ContractTemplate::VERSION}", response.body
    assert_match "article 1590 du Code civil", response.body
    assert_nil @contract.reload.otp_digest, "aucun code n'est généré sur un simple affichage"
    assert_select "form[action=?] button", request_otp_reservation_path(@booking.token), text: /Recevoir mon code/
    assert_no_match "cdn.jsdelivr.net", response.body, "signature_pad est embarquée, pas chargée depuis un CDN"
  end

  test "POST request_otp generates a digest, sends the code and counts the send" do
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      post request_otp_reservation_url(@booking.token)
    end
    @contract.reload
    assert @contract.otp_digest.present?
    assert_equal 1, @contract.otp_sends_count
    assert_redirected_to contract_reservation_path(@booking.token)

    get contract_reservation_url(@booking.token)
    assert_select "button", text: /Renvoyer le code/
  end

  test "request_otp is rate limited per contract link" do
    3.times { post request_otp_reservation_url(@booking.token) }
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      post request_otp_reservation_url(@booking.token)
    end
    assert_redirected_to contract_reservation_path(@booking.token)
    assert_match "Trop de demandes", flash[:alert]
  end

  test "too many code sends lock the contract" do
    Contract::OTP_MAX_SENDS.times { @contract.generate_otp! }
    assert @contract.otp_locked?
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      post request_otp_reservation_url(@booking.token)
    end
    get contract_reservation_url(@booking.token)
    assert_select "[data-contract-locked]"
  end

  test "wrong codes keep counting even after a new code is sent (lock not bypassable)" do
    @contract.generate_otp!
    4.times { sign!("000000") }
    assert_equal 4, @contract.reload.otp_attempts
    @contract.generate_otp! # renvoi : le compteur d'essais ne repart pas à zéro
    assert_equal 4, @contract.reload.otp_attempts
    sign!("000000")
    assert @contract.reload.otp_locked?
    assert_not @contract.status_signed?
  end

  test "a cancelled contract cannot be signed nor receive a code" do
    @contract.update!(status: :cancelled)
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      post request_otp_reservation_url(@booking.token)
    end
    assert_redirected_to reservation_path(@booking.token)
    sign!("123456")
    assert_redirected_to reservation_path(@booking.token)
    assert_not @contract.reload.status_signed?
  end

  test "POST sign_contract rejects an OTP that is not 6 digits" do
    @contract.generate_otp!
    sign!("abc12")
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "POST sign_contract rejects a too-small signature image (empty canvas)" do
    code = @contract.generate_otp!
    sign!(code, image: FAKE_PNG_TINY)
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "POST sign_contract rejects without OTP" do
    post sign_contract_reservation_url(@booking.token),
         params: { signature_image: FAKE_PNG_BIG, accepted: "1" }
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "POST sign_contract rejects with wrong OTP and increments attempts" do
    @contract.generate_otp!
    sign!("000000")
    assert_response :unprocessable_entity
    assert_equal 1, @contract.reload.otp_attempts
    assert_not @contract.status_signed?
  end

  test "POST sign_contract refuses if the checkbox isn't ticked" do
    code = @contract.generate_otp!
    sign!(code, accepted: "0")
    assert_response :unprocessable_entity
    assert_not @contract.reload.status_signed?
  end

  test "signature_image must be a data URL image" do
    code = @contract.generate_otp!
    sign!(code, image: "not a data url")
    assert_response :unprocessable_entity
  end

  test "POST sign_contract with valid OTP signs, freezes the text, records proof and enqueues the PDF job" do
    code = @contract.generate_otp!
    assert_enqueued_with(job: GenerateSignedContractPdfJob) do
      sign!(code)
    end
    assert_redirected_to contract_reservation_path(@booking.token)
    @contract.reload
    assert @contract.status_signed?
    assert_not_nil @contract.signed_at
    assert @contract.signed_ip.present?
    assert_equal 64, @contract.document_hash.length, "hash SHA-256 hex (64 chars)"
    assert_nil @contract.otp_digest, "digest OTP purgé après signature"
    assert_equal ContractTemplate::VERSION, @contract.template_version
    assert_equal @contract.compute_document_hash(@contract.canonical_text), @contract.document_hash
    assert @contract.integrity_ok?
    assert_not @contract.signed_pdf.attached?, "le PDF est produit par le job, pas dans la requête"

    # La page signée indique que le PDF arrive.
    get contract_reservation_url(@booking.token)
    assert_select "[data-pdf-pending]"
  end

  test "the background job attaches the PDF and emails it to the client, once" do
    code = @contract.generate_otp!
    perform_enqueued_jobs do
      sign!(code)
    end
    @contract.reload
    assert @contract.signed_pdf.attached?
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @booking.email ], mail.to
    assert_match "contrat signé", mail.subject.downcase
    assert mail.attachments.any? { |a| a.filename.start_with?("contrat-signe-") }

    # Rejouer le job (nouvelle tentative) ne renvoie pas l'email.
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      GenerateSignedContractPdfJob.perform_now(@contract)
    end
  end

  test "once signed, the frozen text survives later changes to the booking" do
    code = @contract.generate_otp!
    sign!(code)
    @contract.reload
    frozen = @contract.canonical_text

    @booking.update_columns(total_price_cents: 999_999, deposit_cents: 1)
    assert_equal frozen, @contract.reload.contract_text
    assert @contract.integrity_ok?
  end
end
