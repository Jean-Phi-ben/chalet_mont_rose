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
end
