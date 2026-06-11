class ReservationsController < ApplicationController
  allow_unauthenticated_access only: %i[create show contract request_otp sign_contract signed_contract_pdf]

  before_action :load_booking_and_contract, only: %i[contract request_otp sign_contract signed_contract_pdf]

  def create
    @booking = Booking.new(booking_params)
    quote = Pricing.quote(@booking.check_in, @booking.check_out, guests_count: @booking.guests_count.to_i)

    unless quote[:bookable]
      redirect_to calendar_path, alert: "La période sélectionnée n'est pas disponible." and return
    end

    @booking.accommodation_cents = quote[:accommodation_cents]
    @booking.cleaning_fee_cents  = quote[:cleaning_cents]
    @booking.tourist_tax_cents   = quote[:tax_cents]
    @booking.total_price_cents   = quote[:total_cents]
    @booking.deposit_cents       = quote[:deposit_cents]

    if @booking.save
      BookingMailer.dispatch(:new_request_to_owner, @booking)
      BookingMailer.dispatch(:acknowledgement_to_client, @booking)
      redirect_to reservation_path(@booking.token),
                  notice: "Votre demande a bien été envoyée. Nous vous répondrons rapidement.",
                  status: :see_other
    else
      redirect_to calendar_path,
                  alert: @booking.errors.full_messages.to_sentence,
                  status: :see_other
    end
  end

  def show
    @booking = Booking.find_by!(token: params[:token])
  end

  # Page de signature électronique simple (SES).
  # Le client doit scroller, saisir l'OTP reçu par email, dessiner sa signature
  # et accepter pour pouvoir signer. L'OTP est envoyé automatiquement à la
  # première ouverture de la page (ou si l'ancien est expiré/déjà consommé).
  def contract
    return if @contract.status_signed?
    return if @contract.otp_locked?
    return if @contract.otp_digest.present? && !@contract.otp_expired?

    code = @contract.generate_otp!
    BookingMailer.dispatch(:contract_otp, @booking, otp_code: code)
    flash.now[:notice] = "Un code à 6 chiffres vient de vous être envoyé par email."
  end

  # POST /reservations/:token/contract/otp — envoie le code OTP par email.
  def request_otp
    if @contract.status_signed?
      redirect_to contract_reservation_path(@contract_token), notice: "Ce contrat est déjà signé." and return
    end
    if @contract.otp_locked?
      redirect_to contract_reservation_path(@contract_token),
                  alert: "Trop de tentatives. Contactez le propriétaire." and return
    end

    code = @contract.generate_otp!
    BookingMailer.dispatch(:contract_otp, @booking, otp_code: code)
    redirect_to contract_reservation_path(@contract_token),
                notice: "Un code à 6 chiffres vient de vous être envoyé par email."
  end

  # POST /reservations/:token/contract/sign — valide l'OTP et finalise.
  def sign_contract
    if @contract.status_signed?
      redirect_to contract_reservation_path(@contract_token), notice: "Ce contrat est déjà signé." and return
    end
    if @contract.otp_locked?
      redirect_to contract_reservation_path(@contract_token),
                  alert: "Trop de tentatives. Contactez le propriétaire." and return
    end

    code  = params[:otp_code].to_s.strip
    image = params[:signature_image].to_s
    accepted = params[:accepted].to_s == "1"

    return reject(:accepted, "Vous devez cocher la case d'engagement.") unless accepted
    return reject(:otp_code, "Format de code invalide (6 chiffres attendus).") unless code.match?(/\A\d{6}\z/)
    return reject(:signature_image, "Tracé de signature manquant ou invalide.") unless signature_image_valid?(image)

    unless @contract.otp_valid?(code)
      @contract.increment!(:otp_attempts)
      return reject(:otp_code, @contract.otp_locked? ? "Trop de tentatives, contrat verrouillé." : "Code OTP invalide ou expiré.")
    end

    Contract.transaction do
      @contract.update_columns(
        status:            Contract.statuses[:signed],
        signed_at:         Time.current,
        signed_ip:         request.remote_ip,
        signed_user_agent: request.user_agent.to_s[0, 500],
        signature_image:   image,
        otp_digest:        nil,
        otp_sent_at:       nil
      )
      canonical_text = ContractTemplate.canonical_text(@booking, @contract)
      hash = @contract.compute_document_hash(canonical_text)
      @contract.update_columns(document_hash: hash)
    end

    GenerateSignedContractPdfJob.perform_now(@contract)
    # Envoi du PDF signé au client (mailer + EmailLog).
    BookingMailer.dispatch(:signed_contract, @booking) if @contract.signed_pdf.attached?

    redirect_to contract_reservation_path(@contract_token), notice: "Contrat signé avec succès. Une copie vous a été envoyée par email."
  end

  # GET /reservations/:token/contract/pdf — téléchargement du PDF signé.
  def signed_contract_pdf
    unless @contract.status_signed? && @contract.signed_pdf.attached?
      redirect_to contract_reservation_path(@contract_token),
                  alert: "Le PDF signé n'est pas encore disponible." and return
    end
    redirect_to rails_blob_path(@contract.signed_pdf, disposition: "attachment"),
                allow_other_host: false
  end

  private

  def load_booking_and_contract
    @booking  = Booking.find_by!(token: params[:token])
    @contract = @booking.contract
    @contract_token = @booking.token
    if @contract.blank?
      redirect_to reservation_path(@booking.token),
                  alert: "Le contrat n'est pas encore disponible." and return
    end
  end

  def reject(field, message)
    @contract.errors.add(field, message)
    flash.now[:alert] = message
    render :contract, status: :unprocessable_entity
  end

  # Vérifie que l'image base64 contient bien un PNG d'au moins ~1 Ko : un
  # canvas vierge produit ~100 octets, un tracé même minimal en fait >500.
  SIGNATURE_MIN_BYTES = 500
  def signature_image_valid?(data_url)
    return false if data_url.blank?
    return false unless data_url.start_with?("data:image/png;base64,")
    payload = data_url.split(",", 2).last
    return false if payload.blank?
    Base64.strict_decode64(payload).bytesize >= SIGNATURE_MIN_BYTES
  rescue ArgumentError
    false
  end

  def booking_params
    params.require(:booking).permit(
      :check_in, :check_out, :guests_count,
      :first_name, :last_name, :email, :phone, :message, :address
    )
  end
end
