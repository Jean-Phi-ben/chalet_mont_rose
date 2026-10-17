# Après signature : génère et attache le PDF du contrat signé, puis l'envoie au
# client. Tourne en arrière-plan (la signature est déjà enregistrée) et se
# relance en cas d'échec ; chaque étape est idempotente.
# Le contrat étant en lecture seule après signature (cf. Contract#prevent_change_after_signature),
# on passe par la branche autorisée signed_pdf_attachment.
class GenerateSignedContractPdfJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(contract)
    return unless contract.status_signed?

    unless contract.signed_pdf.attached?
      contract.signed_pdf.attach(
        io: StringIO.new(ContractPdf.render(contract)),
        filename: "contrat-signe-#{contract.booking.token}.pdf",
        content_type: "application/pdf"
      )
    end

    return if EmailLog.exists?(booking_id: contract.booking_id, action: "signed_contract")

    BookingMailer.dispatch(:signed_contract, contract.booking)
  end
end
