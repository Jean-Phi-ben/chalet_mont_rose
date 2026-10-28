class BookingMailer < ApplicationMailer
  # Notification au propriétaire à chaque nouvelle demande.
  def new_request_to_owner(booking)
    @booking = booking
    owner = ENV["MAILER_OWNER_EMAIL"].presence || ENV["MAILER_FROM"].presence
    message = mail(to: owner, reply_to: booking.email,
                   subject: "Nouvelle demande de réservation — #{booking.full_name}")
    if owner.blank?
      # Pas de destinataire configuré : on journalise au lieu de lever (le client,
      # lui, reçoit son accusé de réception). Le bandeau admin signale le réglage manquant.
      Rails.logger.error "[BookingMailer] MAILER_OWNER_EMAIL / MAILER_FROM absents : notification propriétaire non envoyée (booking=#{booking.id})"
      message.perform_deliveries = false
    end
    message
  end

  # Accusé de réception envoyé au client.
  def acknowledgement_to_client(booking)
    @booking = booking
    mail to: booking.email,
         subject: "Votre demande de réservation — Chalet Mont Rose"
  end

  # Notifie le client que sa demande n'a pas pu être retenue.
  def rejected(booking)
    @booking = booking
    mail to: booking.email,
         subject: "Votre demande de réservation n'a pas pu être retenue — Chalet Mont Rose"
  end

  # Email de confirmation : facture d'arrhes en PJ + lien signature contrat.
  # La caution Swikly sera envoyée séparément avec le rappel solde J-10.
  def confirmation(booking)
    @booking         = booking
    @deposit_invoice = booking.deposit_invoice
    @contract        = booking.contract
    @contract_url    = @contract ? contract_reservation_url(@booking.token) : nil

    if @deposit_invoice&.pdf&.attached?
      attachments["facture-arrhes-#{@deposit_invoice.number}.pdf"] = @deposit_invoice.pdf.download
    end

    mail to: booking.email,
         subject: "Votre réservation est confirmée — Chalet Mont Rose"
  end

  # Rappel automatique Invoice::BALANCE_REMINDER_DAYS jours avant l'arrivée :
  # solde + caution + documents. Pièces jointes (seulement celles qui existent,
  # listées dans @attached) : facture de solde, contrat signé, conditions, livret.
  # Le lien Swikly de dépôt de caution est inclus dans le corps. Propriétaire en CC.
  def balance_reminder(booking)
    @booking         = booking
    @balance_invoice = booking.balance_invoice
    @balance_amount  = @balance_invoice&.amount_cents || Invoice.balance_amount_for(booking)
    @due_date        = @balance_invoice&.due_on || (booking.check_in - Invoice::BALANCE_DUE_DAYS)
    @reservation_url = reservation_url(@booking.token)
    @caution         = booking.caution
    @caution_url     = @caution&.depositable? ? @caution.deposit_url : nil
    @attached        = []

    attach_pdf(@balance_invoice&.pdf,        "facture-solde-#{@balance_invoice&.number}.pdf", "Facture de solde (PDF)") if @balance_invoice
    attach_pdf(booking.contract&.signed_pdf, "contrat-signe-#{booking.token}.pdf",            "Contrat de location signé (PDF)")
    Document.find_each do |doc|
      next unless doc.file.attached?

      attachments[doc.file.filename.to_s] = doc.file.download
      @attached << doc.title
    end

    cc = ENV["MAILER_OWNER_EMAIL"].presence
    mail to: booking.email,
         cc: cc,
         subject: "Solde, caution et infos pratiques — Chalet Mont Rose"
  end

  # Une fois le contrat signé, envoi du PDF complet au client.
  def signed_contract(booking)
    @booking  = booking
    @contract = booking.contract
    @signed_at = @contract&.signed_at
    @hash      = @contract&.document_hash

    if @contract&.signed_pdf&.attached?
      attachments["contrat-signe-#{booking.token}.pdf"] = @contract.signed_pdf.download
    end

    mail to: booking.email,
         subject: "Votre contrat signé — Chalet Mont Rose"
  end

  # Code OTP à 6 chiffres pour autoriser la signature.
  # Passé via kwarg otp_code: depuis BookingMailer.dispatch.
  def contract_otp(booking, otp_code:)
    @booking   = booking
    @otp_code  = otp_code
    @ttl_mins  = Contract::OTP_TTL.in_minutes.to_i
    mail to: booking.email,
         subject: "Votre code de signature — Chalet Mont Rose"
  end

  private

  def attach_pdf(active_storage_attachment, filename, label = nil)
    return unless active_storage_attachment&.attached?

    attachments[filename] = active_storage_attachment.download
    @attached << label if label && @attached
  end
end
