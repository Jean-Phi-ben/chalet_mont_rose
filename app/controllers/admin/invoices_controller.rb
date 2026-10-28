class Admin::InvoicesController < Admin::BaseController
  before_action :set_invoice, only: %i[show update mark_received mark_awaiting archive]

  def index
    @archived_mode = false
    list_bookings(Booking.where("check_out >= ?", Date.current))
  end

  def archived
    @archived_mode = true
    list_bookings(Booking.where("check_out < ?", Date.current))
    render :index
  end

  # La fiche d'une facture montre les deux factures (arrhes + solde) de la réservation.
  def show
    authorize @invoice
    @booking = @invoice.booking
  end

  # Mise à jour libre d'une facture (date de réception saisie à la main, etc.).
  def update
    authorize @invoice
    if @invoice.booking.invoicing_archived?
      return redirect_to admin_invoice_path(@invoice), alert: "Facturation verrouillée — modification impossible."
    end
    if @invoice.update(invoice_params)
      GenerateInvoiceJob.perform_now(@invoice.booking)
      redirect_to admin_invoice_path(@invoice), notice: "Facture mise à jour."
    else
      redirect_to admin_invoice_path(@invoice), alert: @invoice.errors.full_messages.to_sentence
    end
  end

  def mark_received
    authorize @invoice
    if @invoice.booking.invoicing_archived?
      return redirect_to admin_invoice_path(@invoice), alert: "Facturation verrouillée — paiement non modifiable."
    end
    # Date saisie dans la fenêtre de confirmation (aujourd'hui par défaut).
    received_on = params.dig(:invoice, :received_on).presence || Date.current
    if @invoice.update(status: :received, received_on: received_on)
      GenerateInvoiceJob.perform_now(@invoice.booking)
      redirect_to admin_invoice_path(@invoice),
                  notice: "Paiement #{@invoice.kind_deposit? ? 'des arrhes' : 'du solde'} enregistré le #{helpers.fr_date(@invoice.received_on)}."
    else
      redirect_to admin_invoice_path(@invoice), alert: @invoice.errors.full_messages.to_sentence
    end
  end

  def mark_awaiting
    authorize @invoice
    if @invoice.booking.invoicing_archived?
      return redirect_to admin_invoice_path(@invoice), alert: "Facturation verrouillée — paiement non modifiable."
    end
    @invoice.mark_awaiting!
    GenerateInvoiceJob.perform_now(@invoice.booking)
    redirect_to admin_invoice_path(@invoice), notice: "Paiement #{@invoice.kind_deposit? ? 'des arrhes' : 'du solde'} annulé."
  end

  # Verrou définitif : la réservation et ses factures ne pourront plus être modifiées.
  def archive
    booking = @invoice.booking
    authorize booking, :archive_invoicing?
    booking.archive_invoicing!
    redirect_to admin_invoice_path(@invoice), notice: "Facturation verrouillée."
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:received_on, :status)
  end

  def list_bookings(scope)
    authorize Invoice, :index?
    @bookings = scope
                  .joins(:invoices)
                  .includes(:invoices)
                  .distinct
                  .order(:check_in, :id)
  end
end
