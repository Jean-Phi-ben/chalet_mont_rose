class ReservationsController < ApplicationController
  allow_unauthenticated_access only: %i[create show contract request_otp sign_contract signed_contract_pdf]

  before_action :load_booking_and_contract, only: %i[contract request_otp sign_contract signed_contract_pdf]
  before_action :require_signable_contract, only: %i[request_otp sign_contract]

  # Limites par lien de contrat : 3 envois de code et 10 tentatives de signature par quart d'heure.
  rate_limit to: 3,  within: 15.minutes, only: :request_otp,  by: -> { params[:token] },
             with: -> { redirect_to contract_reservation_path(params[:token]), alert: "Trop de demandes de code : réessayez dans quelques minutes." }
  rate_limit to: 10, within: 15.minutes, only: :sign_contract, by: -> { params[:token] },
             with: -> { redirect_to contract_reservation_path(params[:token]), alert: "Trop de tentatives : réessayez dans quelques minutes." }

  def create
    @booking = Booking.new(booking_params)
    quote = Pricing.quote(@booking.check_in, @booking.check_out,
                          guests_count: @booking.guests_count.to_i, earliest_check_in: Date.current)

    unless quote[:bookable]
      redirect_to root_path(anchor: "disponibilites"), flash: { calendar_alert: "La période sélectionnée n'est pas disponible." } and return
    end

    @booking.accommodation_cents = quote[:accommodation_cents]
    @booking.cleaning_fee_cents  = quote[:cleaning_cents]
    @booking.tourist_tax_cents   = quote[:tax_cents]
    @booking.total_price_cents   = quote[:total_cents]
    @booking.deposit_cents       = quote[:deposit_cents]

    if @booking.save
      # Emails en arrière-plan : une panne SMTP ne doit pas renvoyer une erreur au
      # client alors que sa demande est enregistrée (le job se relance).
      DeliverBookingEmailJob.perform_later(:new_request_to_owner, @booking)
      DeliverBookingEmailJob.perform_later(:acknowledgement_to_client, @booking)
      redirect_to reservation_path(@booking.token),
                  notice: "Votre demande a bien été envoyée. Nous vous répondrons rapidement.",
                  status: :see_other
    else
      redirect_to root_path(anchor: "disponibilites"),
                  flash: { calendar_alert: @booking.errors.full_messages.to_sentence },
                  status: :see_other
    end
  end

  def show
    @booking = Booking.find_by!(token: params[:token])
  end

  # Page de signature électronique simple (SES). Aucun effet de bord : le code
  # n'est envoyé que sur demande explicite (POST request_otp), jamais sur un GET
  # (préchargement Turbo, antivirus qui suivent les liens…).
  def contract
  end

  # POST /reservations/:token/contract/otp — envoie le code OTP par email.
  def request_otp
    code = @contract.generate_otp!
    BookingMailer.dispatch(:contract_otp, @booking, otp_code: code)
    redirect_to contract_reservation_path(@contract_token),
                notice: "Un code à 6 chiffres vient de vous être envoyé par email."
  end

  # POST /reservations/:token/contract/sign — valide l'OTP et finalise.
  def sign_contract
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

    # Le texte haché est gelé en base avec le contrat : il ne sera plus jamais
    # recalculé (template, locale ou réservation peuvent changer ensuite).
    canonical_text = ContractTemplate.canonical_text(@booking, @contract)
    Contract.transaction do
      @contract.update_columns(
        status:            Contract.statuses[:signed],
        signed_at:         Time.current,
        signed_ip:         request.remote_ip,
        signed_user_agent: request.user_agent.to_s[0, 500],
        signature_image:   image,
        canonical_text:    canonical_text,
        template_version:  ContractTemplate::VERSION,
        otp_digest:        nil,
        otp_sent_at:       nil
      )
      @contract.update_columns(document_hash: @contract.compute_document_hash(canonical_text))
    end

    # PDF et email en arrière-plan : la signature est acquise, un incident de
    # génération ne doit pas afficher d'erreur au client (le job se relance).
    GenerateSignedContractPdfJob.perform_later(@contract)

    redirect_to contract_reservation_path(@contract_token),
                notice: "Contrat signé avec succès. Une copie signée vous sera envoyée par email dans quelques instants."
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

  # Envoi de code et signature : uniquement un contrat envoyé, non signé, non verrouillé.
  def require_signable_contract
    if @contract.status_signed?
      redirect_to contract_reservation_path(@contract_token), notice: "Ce contrat est déjà signé."
    elsif @contract.otp_locked?
      redirect_to contract_reservation_path(@contract_token),
                  alert: "Signature verrouillée après trop de tentatives : contactez le propriétaire pour la débloquer."
    elsif !@contract.status_sent?
      redirect_to reservation_path(@booking.token), alert: "Ce contrat n'est pas (ou plus) proposé à la signature."
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
