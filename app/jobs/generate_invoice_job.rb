# Crée ou met à jour les DEUX factures d'une réservation confirmée (arrhes + solde)
# et (re)génère leur PDF — uniquement pour les factures non verrouillées et
# seulement si leur contenu a changé (empreinte). Une facture payée ne bouge plus.
class GenerateInvoiceJob < ApplicationJob
  queue_as :default

  # force: true → régénère le PDF des factures non verrouillées même si rien n'a changé.
  def perform(booking, force: false)
    # Les arrhes d'abord : le solde (montant et PDF) dépend de la facture d'arrhes.
    [ :deposit, :balance ].each do |kind|
      invoice = booking.invoices.find_by(kind: kind) || booking.invoices.new(kind: kind)
      locked  = invoice.persisted? && invoice.locked?

      unless locked
        invoice.amount_cents = amount_for(booking, kind)
        invoice.issued_on ||= Date.current
        invoice.save!
      end

      # Facture verrouillée : son PDF ne change plus (on ne le crée que s'il manque).
      next if locked && invoice.pdf.attached?

      fingerprint = fingerprint_for(invoice)
      next if !force && invoice.pdf.attached? && invoice.pdf_fingerprint == fingerprint

      invoice.pdf.attach(
        io:           StringIO.new(InvoicePdf.render(invoice)),
        filename:     "#{invoice.number}.pdf",
        content_type: "application/pdf"
      )
      invoice.update_column(:pdf_fingerprint, fingerprint)
    end
  end

  private

  def amount_for(booking, kind)
    case kind
    when :deposit then booking.deposit_cents.to_i
    when :balance then Invoice.balance_amount_for(booking)
    end
  end

  # Empreinte de tout ce qui apparaît sur le PDF : tant qu'elle est identique,
  # le PDF existant reste exact et n'est pas régénéré.
  def fingerprint_for(invoice)
    booking = invoice.booking
    deposit = booking.deposit_invoice
    payload = {
      layout:  InvoicePdf::LAYOUT_VERSION,
      invoice: invoice.slice(:kind, :number, :issued_on, :amount_cents),
      booking: booking.slice(:check_in, :check_out, :guests_count, :first_name, :last_name, :email, :phone,
                             :accommodation_cents, :cleaning_fee_cents, :tourist_tax_cents,
                             :total_price_cents, :deposit_cents),
      address: booking.client&.address,
      deposit: deposit&.slice(:number, :amount_cents, :status, :received_on),
      vat:     Booking::VAT_RATES,
      due:     [ Invoice::DEPOSIT_DUE_DAYS, Invoice::BALANCE_DUE_DAYS ],
      company: ENV.select { |k, _| k.start_with?("COMPANY_") }.sort
    }
    Digest::SHA256.hexdigest(payload.to_json)
  end
end
