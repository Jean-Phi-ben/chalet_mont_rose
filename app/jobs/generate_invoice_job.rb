# Génère (ou régénère) les DEUX factures d'une réservation confirmée : arrhes + solde.
# Le PDF de chaque facture est (re)créé selon les montants courants du booking.
class GenerateInvoiceJob < ApplicationJob
  queue_as :default

  def perform(booking)
    [ :deposit, :balance ].each do |kind|
      invoice = booking.invoices.find_by(kind: kind) || booking.invoices.new(kind: kind)
      invoice.amount_cents = amount_for(booking, kind)
      invoice.issued_on ||= Date.current
      invoice.save!

      invoice.pdf.attach(
        io:           StringIO.new(InvoicePdf.render(invoice)),
        filename:     "#{invoice.number}.pdf",
        content_type: "application/pdf"
      )
    end
  end

  private

  def amount_for(booking, kind)
    case kind
    when :deposit then booking.deposit_cents.to_i
    when :balance then Invoice.balance_amount_for(booking)
    end
  end
end
