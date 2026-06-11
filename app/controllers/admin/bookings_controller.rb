class Admin::BookingsController < Admin::BaseController
  before_action :set_booking, only: %i[show edit update confirm reject cancel destroy send_balance_reminder resend_email]

  # Emails transactionnels renvoyables depuis la fiche réservation :
  #   - confirmation     : facture arrhes + lien contrat + lien caution
  #   - signed_contract  : PDF du contrat signé
  #   - balance_reminder : rappel J-10 + facture solde + contrat signé + CGU/livret
  RESENDABLE_MAILER_ACTIONS = %w[confirmation signed_contract balance_reminder].freeze

  def index
    @archived_mode = false
    list_bookings(Booking.where("check_out >= ?", Date.current))
  end

  def archived
    @archived_mode = true
    list_bookings(Booking.where("check_out < ?", Date.current))
    render :index
  end

  def show
    authorize @booking
    @conflicts   = @booking.conflicting_bookings
    @email_logs  = EmailLog.where(booking_id: @booking.id).recent
    @planned_emails = BookingEmailPlanner.for(@booking)
  end

  def new
    @booking = Booking.new
    authorize @booking
  end

  def create
    @booking = Booking.new(booking_params)
    authorize @booking
    compute_pricing(@booking,
                    override: params.dig(:booking, :accommodation_euros).presence,
                    cleaning_override: params.dig(:booking, :cleaning_fee_euros).presence)

    if @booking.errors.empty? && @booking.save
      redirect_to admin_booking_path(@booking), notice: "Réservation créée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @booking
  end

  def update
    authorize @booking
    @booking.assign_attributes(booking_params)
    compute_pricing(@booking,
                    override: params.dig(:booking, :accommodation_euros).presence,
                    cleaning_override: params.dig(:booking, :cleaning_fee_euros).presence,
                    deposit_override: params.dig(:booking, :deposit_euros).presence)

    if @booking.errors.empty? && @booking.save
      GenerateInvoiceJob.perform_now(@booking) if @booking.confirmed? && @booking.invoices.any?
      redirect_to admin_booking_path(@booking), notice: "Réservation mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm
    authorize @booking
    unless @booking.update(status: :confirmed)
      redirect_to admin_booking_path(@booking), alert: @booking.errors.full_messages.to_sentence and return
    end

    # À la confirmation : facture des arrhes + contrat à signer.
    # La caution Swikly est créée plus tard, en même temps que le rappel solde J-10.
    warnings = []
    GenerateInvoiceJob.perform_now(@booking)
    begin
      SendContractJob.perform_now(@booking)
    rescue StandardError => e
      warnings << "contrat : #{e.message}"
    end

    BookingMailer.dispatch(:confirmation, @booking)

    if warnings.empty?
      redirect_to admin_booking_path(@booking),
                  notice: "Réservation confirmée — email envoyé (facture arrhes + lien signature)."
    else
      redirect_to admin_booking_path(@booking),
                  alert: "Confirmée et email envoyé. Étapes en échec : #{warnings.join(' · ')}"
    end
  end

  def reject
    authorize @booking
    if @booking.update(status: :rejected)
      BookingMailer.dispatch(:rejected, @booking)
      redirect_to admin_booking_path(@booking), notice: "Demande refusée — le client a été notifié."
    else
      redirect_to admin_booking_path(@booking), alert: @booking.errors.full_messages.to_sentence
    end
  end

  def cancel
    authorize @booking
    if @booking.update(status: :cancelled)
      redirect_to admin_booking_path(@booking), notice: "Réservation annulée."
    else
      redirect_to admin_booking_path(@booking), alert: @booking.errors.full_messages.to_sentence
    end
  end

  # Envoi manuel du rappel solde (utile quand le job récurrent n'a pas tourné
  # ou que la date J-10 est dépassée pour ce booking).
  def send_balance_reminder
    authorize @booking, :send_balance_reminder?
    # La caution Swikly est créée à ce moment-là (avant le rappel) pour que
    # le lien de dépôt soit inclus dans l'email.
    begin
      CreateCautionJob.perform_now(@booking)
    rescue SwiklyProvider::Error => e
      Rails.logger.warn "[send_balance_reminder] caution : #{e.message}"
    end
    BookingMailer.dispatch(:balance_reminder, @booking)
    @booking.balance_invoice&.update!(balance_reminder_sent_at: Time.current)
    redirect_to admin_booking_path(@booking), notice: "Rappel solde envoyé (facture solde + caution + livret)."
  rescue StandardError => e
    redirect_to admin_booking_path(@booking),
                alert: "Échec de l'envoi du rappel : #{e.message}"
  end

  # Renvoie un email déjà émis (avec attachments régénérés depuis l'état
  # courant de la résa). Limité à un set blanc d'actions du BookingMailer.
  def resend_email
    authorize @booking, :send_balance_reminder?
    action = params[:mailer_action].to_s
    unless RESENDABLE_MAILER_ACTIONS.include?(action)
      redirect_to admin_booking_path(@booking), alert: "Action email inconnue." and return
    end

    BookingMailer.dispatch(action.to_sym, @booking)
    redirect_to admin_booking_path(@booking), notice: "Email « #{action.humanize} » renvoyé."
  rescue StandardError => e
    redirect_to admin_booking_path(@booking), alert: "Échec du renvoi : #{e.message}"
  end

  def destroy
    authorize @booking
    @booking.destroy!
    redirect_to admin_bookings_path, notice: "Demande de réservation supprimée."
  end

  private

  def set_booking
    @booking = Booking.find(params[:id])
  end

  def booking_params
    params.require(:booking).permit(:check_in, :check_out, :guests_count,
                                    :first_name, :last_name, :email, :phone, :message,
                                    :address, :accommodation_euros, :cleaning_fee_euros, :deposit_euros)
  end

  # Applique le devis et le décompte. Overrides admin facultatifs pour hébergement / ménage / arrhes.
  def compute_pricing(booking, override: nil, cleaning_override: nil, deposit_override: nil)
    return unless booking.valid?

    quote = Pricing.quote(booking.check_in, booking.check_out,
                          guests_count: booking.guests_count.to_i, except_id: booking.id)
    unless quote[:bookable]
      booking.errors.add(:base, "Période indisponible : #{quote_reason(quote[:reason])}.")
      return
    end

    booking.accommodation_cents = quote[:accommodation_cents] unless override
    cleaning_cents = cleaning_override.present? ? (cleaning_override.to_d * 100).round : nil
    deposit_cents  = deposit_override.present?  ? (deposit_override.to_d * 100).round  : nil
    booking.apply_breakdown!(cleaning_override_cents: cleaning_cents, deposit_override_cents: deposit_cents)
  end

  # Charge la liste (active ou archivée) en appliquant chips de statut + tri +
  # filtre par période (params :from / :to au format YYYY-MM-DD).
  def list_bookings(base_scope)
    authorize Booking, :index?
    scope = policy_scope(Booking).merge(base_scope)
    scope = scope.where(status: params[:status]) if Booking.statuses.key?(params[:status].to_s)
    @from = parse_date(params[:from])
    @to   = parse_date(params[:to])
    scope = scope.where("check_out >= ?", @from) if @from
    scope = scope.where("check_in <= ?", @to)   if @to
    @status_counts = policy_scope(Booking).merge(base_scope).group(:status).count
    # Eager loading pour éviter N+1 sur les pastilles paiements / docs.
    @bookings = scope.includes(:contract, :caution, invoices: { pdf_attachment: :blob }).order(sort_clause)
  end

  def parse_date(value)
    Date.parse(value.to_s)
  rescue StandardError
    nil
  end

  # Tri demandé via les en-têtes cliquables (Demande / Période).
  # Défaut : tri par période ascendante (séjours à venir d'abord).
  def sort_clause
    sort = params[:sort].presence || "check_in"
    dir  = params[:dir].presence || (sort == "check_in" ? "asc" : "desc")
    direction = dir == "asc" ? "ASC" : "DESC"
    case sort
    when "check_in" then "check_in #{direction}, created_at DESC"
    else                 "created_at #{direction}"
    end
  end

  def quote_reason(code)
    {
      "samedi_requis"        => "les dates doivent être des samedis",
      "ordre_invalide"       => "la date de départ doit suivre l'arrivée",
      "semaine_non_tarifee"  => "une ou plusieurs semaines ne sont pas tarifées",
      "semaine_indisponible" => "la période chevauche une réservation confirmée"
    }.fetch(code, "période invalide")
  end
end
