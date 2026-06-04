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
      return redirect_to admin_invoice_path(@invoice), alert: "Facturation archivée — modification impossible."
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
      return redirect_to admin_invoice_path(@invoice), alert: "Facturation archivée — paiement non modifiable."
    end
    @invoice.mark_received!
    GenerateInvoiceJob.perform_now(@invoice.booking)
    redirect_to admin_invoice_path(@invoice), notice: "#{@invoice.label} marquée comme reçue."
  end

  def mark_awaiting
    authorize @invoice
    if @invoice.booking.invoicing_archived?
      return redirect_to admin_invoice_path(@invoice), alert: "Facturation archivée — paiement non modifiable."
    end
    @invoice.mark_awaiting!
    GenerateInvoiceJob.perform_now(@invoice.booking)
    redirect_to admin_invoice_path(@invoice), notice: "Paiement de #{@invoice.label.downcase} annulé."
  end

  # Verrou définitif : la réservation et ses factures ne pourront plus être modifiées.
  def archive
    booking = @invoice.booking
    authorize booking, :archive_invoicing?
    booking.archive_invoicing!
    redirect_to admin_invoice_path(@invoice), notice: "Facturation archivée."
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
