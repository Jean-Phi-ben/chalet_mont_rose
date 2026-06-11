class BookingMailer < ApplicationMailer
  # Notification au propriétaire à chaque nouvelle demande.
  def new_request_to_owner(booking)
    @booking = booking
    owner = ENV["MAILER_OWNER_EMAIL"].presence || ENV["MAILER_FROM"].presence
    mail to: owner,
         reply_to: booking.email,
         subject: "Nouvelle demande de réservation — #{booking.full_name}"
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
         subject: "Votre demande de réservation — Chalet Mont Rose"
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

  # Rappel automatique J-BALANCE_REMINDER_DAYS : solde + caution + livret.
  # Pièces jointes : facture de solde + contrat signé + CGU + livret.
  # Le lien Swikly de dépôt de caution est inclus dans le corps de l'email.
  # Admin en CC.
  def balance_reminder(booking)
    @booking         = booking
    @balance_amount  = Invoice.balance_amount_for(booking)
    @balance_invoice = booking.balance_invoice
    @due_date        = booking.check_in - (ENV["BALANCE_REMINDER_DAYS"].presence&.to_i || 10)
    @reservation_url = reservation_url(@booking.token)
    @caution         = booking.caution
    @caution_url     = @caution&.depositable? ? @caution.deposit_url : nil

    attach_pdf(@balance_invoice&.pdf,            "facture-solde-#{@balance_invoice&.number}.pdf") if @balance_invoice
    attach_pdf(booking.contract&.signed_pdf,     "contrat-signe-#{booking.token}.pdf")
    Document.find_each do |doc|
      next unless doc.file.attached?
      attachments[doc.file.filename.to_s] = doc.file.download
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

  def attach_pdf(active_storage_attachment, filename)
    return unless active_storage_attachment&.attached?
    attachments[filename] = active_storage_attachment.download
  end
end
