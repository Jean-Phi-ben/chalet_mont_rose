# Calcule les emails automatiques à venir pour une réservation donnée
# (envois planifiés non encore réalisés). Utilisé sur la page admin pour
# afficher la timeline complète : passé + futur.
class BookingEmailPlanner
  include ApplicationHelper # fr_date_full

  PlannedEmail = Struct.new(:label, :scheduled_for, :description, :overdue, keyword_init: true)

  def self.for(booking)
    new(booking).call
  end

  def initialize(booking)
    @booking = booking
  end

  def call
    return [] unless @booking.confirmed?

    planned = []
    planned << balance_reminder if balance_reminder_pending?
    planned
  end

  private

  def balance_reminder_pending?
    return false unless @booking.balance_invoice
    return false if @booking.balance_invoice.balance_reminder_sent_at.present?
    return false if @booking.balance_invoice.payment_received?
    # On affiche tant que le séjour n'est pas commencé, même si la date d'envoi
    # est dépassée (le rappel devient « en retard » et peut être envoyé manuellement).
    @booking.check_in >= Date.current
  end

  def balance_reminder
    overdue = balance_reminder_date < Date.current
    date_str = fr_date_full(balance_reminder_date)
    if overdue
      desc = "La date d'envoi automatique (#{date_str}) est dépassée — à envoyer manuellement."
    else
      desc = "Sera envoyé automatiquement le matin du #{date_str} : facture de solde, caution, contrat signé, conditions et livret."
    end

    PlannedEmail.new(
      label: "Rappel solde J-#{balance_reminder_days}",
      scheduled_for: balance_reminder_date,
      description: desc,
      overdue: overdue
    )
  end

  def balance_reminder_date
    @booking.check_in - balance_reminder_days
  end

  def balance_reminder_days
    Invoice::BALANCE_REMINDER_DAYS
  end
end
