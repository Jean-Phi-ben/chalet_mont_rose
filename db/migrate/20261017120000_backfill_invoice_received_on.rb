# Factures marquées payées sans date de paiement (statut changé depuis l'admin sans
# saisir la date) : on prend la date de dernière modification, au plus proche du
# moment où le paiement a été enregistré. Désormais garanti par le modèle (before_save).
class BackfillInvoiceReceivedOn < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE invoices
      SET received_on = updated_at::date
      WHERE status = 1 AND received_on IS NULL
    SQL
  end

  def down
    # Irréversible sans perte : on ne sait plus quelles dates ont été déduites.
  end
end
