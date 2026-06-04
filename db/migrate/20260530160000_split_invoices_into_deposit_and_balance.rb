class SplitInvoicesIntoDepositAndBalance < ActiveRecord::Migration[8.1]
  def up
    # Flag d'archivage explicite sur la réservation (verrou définitif).
    add_column :bookings, :invoicing_archived_at, :datetime

    # Nouvelles colonnes : chaque invoice = arrhes OU solde, un seul montant + un seul statut.
    add_column :invoices, :kind,         :integer, default: 0, null: false
    add_column :invoices, :amount_cents, :integer, default: 0, null: false
    add_column :invoices, :status,       :integer, default: 0, null: false
    add_column :invoices, :received_on,  :date

    # L'ancien index unique sur booking_id (has_one) doit céder la place à (booking_id, kind).
    remove_index :invoices, :booking_id if index_exists?(:invoices, :booking_id)
    add_index :invoices, :booking_id
    add_index :invoices, %i[booking_id kind], unique: true

    # Migration des données : 1 invoice existante → 2 (arrhes + solde).
    Invoice.reset_column_information
    Booking.reset_column_information

    Invoice.unscoped.find_each do |inv|
      # L'existant devient la facture d'arrhes.
      inv.update_columns(
        kind: 0,
        amount_cents: inv["deposit_cents"].to_i,
        status: inv["deposit_status"].to_i,
        received_on: inv["deposit_received_on"]
      )

      # Création de la facture de solde correspondante.
      year = inv.issued_on.year
      last = Invoice.unscoped.where("number LIKE ?", "CMR-#{year}-%").order(number: :desc).first
      next_seq = last.number.split("-").last.to_i + 1

      Invoice.unscoped.create!(
        booking_id:    inv.booking_id,
        kind:          1,
        amount_cents:  inv["balance_cents"].to_i,
        status:        inv["balance_status"].to_i,
        received_on:   inv["balance_received_on"],
        issued_on:     inv.issued_on,
        number:        format("CMR-%d-%04d", year, next_seq),
        total_cents:   inv["total_cents"].to_i,
        deposit_cents: inv["deposit_cents"].to_i,
        balance_cents: inv["balance_cents"].to_i
      )
    end

    # On supprime les colonnes désormais redondantes.
    remove_column :invoices, :total_cents
    remove_column :invoices, :deposit_cents
    remove_column :invoices, :balance_cents
    remove_column :invoices, :deposit_status
    remove_column :invoices, :deposit_received_on
    remove_column :invoices, :balance_status
    remove_column :invoices, :balance_received_on
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
