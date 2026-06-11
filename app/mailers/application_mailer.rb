class ApplicationMailer < ActionMailer::Base
  helper ApplicationHelper
  helper MoneyHelper
  default from: -> { ENV["MAILER_FROM"].presence || "Chalet Mont Rose <noreply@example.com>" }
  layout "mailer"

  # API simple : construit le mail, l'envoie en synchrone, puis crée l'EmailLog.
  # Tout dans le même thread → pas de race condition, pas de callback fragile.
  # Usage : BookingMailer.confirmation(booking).send_and_log!
  def self.dispatch(mailer_action, *args, **kwargs)
    delivery = public_send(mailer_action, *args, **kwargs)
    delivery.deliver_now
    EmailLog.record!(delivery.message,
                     mailer: name,
                     action: mailer_action,
                     booking: extract_booking(args, kwargs))
    delivery
  end

  def self.extract_booking(args, kwargs)
    candidate = args.find { |a| a.is_a?(Booking) } || kwargs.values.find { |v| v.is_a?(Booking) }
    candidate
  end
end
