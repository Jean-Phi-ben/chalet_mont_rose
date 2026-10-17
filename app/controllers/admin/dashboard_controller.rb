class Admin::DashboardController < Admin::BaseController
  RECEIVED_INVOICES_LIMIT = 10

  def index
    @weekly_rates_count = WeeklyRate.count
    @notes = Note.active.sorted
    @note  = Note.new

    # Demandes de réservation en attente de validation, par date d'arrivée.
    @pending_bookings = Booking.pending.order(:check_in, :id)

    # Factures à venir : non payées, réservations confirmées, triées par échéance
    # (calculée en Ruby : J+7 de l'émission pour les arrhes, J-10 de l'arrivée pour le solde).
    @upcoming_invoices = Invoice.payment_awaiting.includes(:booking)
                                .where(booking: Booking.confirmed)
                                .sort_by { |i| [ i.due_on, i.id ] }
    # Factures encaissées : les plus récentes d'abord.
    received = Invoice.payment_received.includes(:booking)
    @received_total_cents = received.sum(:amount_cents)
    @received_invoices    = received.order(received_on: :desc, id: :desc).limit(RECEIVED_INVOICES_LIMIT)
  end
end
