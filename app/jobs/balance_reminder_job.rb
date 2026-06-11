# Tâche quotidienne (Solid Queue recurring) : envoie au client le rappel
# du solde à J-BALANCE_REMINDER_DAYS avant l'arrivée, avec CGU + livret +
# facture de solde + contrat signé en pièces jointes, admin en CC.
#
# Anti-doublon : on stocke balance_reminder_sent_at sur la facture de solde
# et on n'envoie qu'une seule fois par réservation.
class BalanceReminderJob < ApplicationJob
  queue_as :default

  def perform(target_date: nil)
    days   = (ENV["BALANCE_REMINDER_DAYS"].presence || "10").to_i
    target = target_date || (Date.current + days)

    bookings_to_remind(target).find_each do |booking|
      next if already_reminded?(booking)
      # On crée la caution Swikly à ce moment-là (J-10) pour que son lien soit
      # inclus dans le mail de rappel. Si l'API échoue, on continue quand
      # même : l'email part avec ce qu'on a (le lien sera juste manquant).
      begin
        CreateCautionJob.perform_now(booking)
      rescue SwiklyProvider::Error => e
        Rails.logger.warn "[BalanceReminderJob] caution booking=#{booking.id} : #{e.message}"
      end
      BookingMailer.dispatch(:balance_reminder, booking)
      booking.balance_invoice&.update!(balance_reminder_sent_at: Time.current)
    end
  end

  private

  def bookings_to_remind(target)
    Booking.where(status: :confirmed, check_in: target)
  end

  # Déjà envoyé ? On regarde le marqueur ou bien si le solde est déjà reçu.
  def already_reminded?(booking)
    inv = booking.balance_invoice
    return true unless inv
    return true if inv.payment_received?
    inv.balance_reminder_sent_at.present?
  end
end
