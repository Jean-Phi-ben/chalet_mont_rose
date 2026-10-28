# Tâche quotidienne (Solid Queue recurring) : envoie au client le rappel du
# solde Invoice::BALANCE_REMINDER_DAYS jours avant l'arrivée, avec facture de
# solde, contrat signé, conditions et livret en pièces jointes, propriétaire en CC.
#
# Fenêtre glissante [aujourd'hui, J+BALANCE_REMINDER_DAYS] : un jour sans
# exécution ou une réservation confirmée tardivement sont rattrapés au passage
# suivant. Anti-doublon : balance_reminder_sent_at sur la facture de solde.
class BalanceReminderJob < ApplicationJob
  queue_as :default

  def perform(target_date: nil)
    horizon = target_date || (Date.current + Invoice::BALANCE_REMINDER_DAYS)

    bookings_to_remind(horizon).find_each do |booking|
      next if already_reminded?(booking)

      remind(booking)
    rescue StandardError => e
      # Une réservation en erreur (SMTP, Swikly…) ne doit pas bloquer les suivantes.
      Rails.logger.error "[BalanceReminderJob] booking=#{booking.id} : #{e.class} #{e.message}"
    end
  end

  private

  def remind(booking)
    # La caution Swikly est créée à ce moment-là pour que son lien figure dans
    # le rappel. Si le prestataire échoue, l'email part sans le lien.
    begin
      CreateCautionJob.perform_now(booking)
    rescue SwiklyProvider::Error => e
      Rails.logger.warn "[BalanceReminderJob] caution booking=#{booking.id} : #{e.message}"
    end
    BookingMailer.dispatch(:balance_reminder, booking)
    booking.balance_invoice&.update!(balance_reminder_sent_at: Time.current)
  end

  def bookings_to_remind(horizon)
    Booking.where(status: :confirmed, check_in: Date.current..horizon)
  end

  # Déjà envoyé ? On regarde le marqueur ou bien si le solde est déjà reçu.
  def already_reminded?(booking)
    inv = booking.balance_invoice
    return true unless inv
    return true if inv.payment_received?

    inv.balance_reminder_sent_at.present?
  end
end
