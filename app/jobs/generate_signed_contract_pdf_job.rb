# Génère et attache le PDF du contrat signé à un Contract.
# Le contrat étant en lecture seule après signature (cf. Contract#prevent_change_after_signature),
# on contourne via la branche autorisée signed_pdf_attachment.
class GenerateSignedContractPdfJob < ApplicationJob
  queue_as :default

  def perform(contract)
    return unless contract.status_signed?
    return if contract.signed_pdf.attached?

    binary = ContractPdf.render(contract)
    contract.signed_pdf.attach(
      io: StringIO.new(binary),
      filename: "contrat-signe-#{contract.booking.token}.pdf",
      content_type: "application/pdf"
    )
  end
end
