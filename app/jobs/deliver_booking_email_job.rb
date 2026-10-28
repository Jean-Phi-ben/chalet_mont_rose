# Envoi différé d'un email de réservation (BookingMailer.dispatch : livraison +
# EmailLog). Utilisé là où l'expéditeur de la requête n'est pas l'admin : une
# panne SMTP ne doit pas afficher une erreur au client dont la demande est
# pourtant enregistrée. Relancé automatiquement en cas d'échec.
class DeliverBookingEmailJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 1.minute, attempts: 3

  def perform(mailer_action, booking)
    BookingMailer.dispatch(mailer_action.to_sym, booking)
  end
end
