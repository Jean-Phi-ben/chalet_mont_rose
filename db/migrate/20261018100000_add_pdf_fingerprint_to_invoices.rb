# Empreinte du contenu du dernier PDF généré : permet de ne régénérer une
# facture que si ce qui y figure a changé (cf. GenerateInvoiceJob).
class AddPdfFingerprintToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :pdf_fingerprint, :string
  end
end
