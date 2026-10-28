# users.admin : le statut admin vient de la liste blanche ADMIN_EMAILS (User#admin?),
# la colonne n'était plus lue. booking_settings.vat_rate_percent : les taux de TVA
# sont fixés dans Booking::VAT_RATES, le réglage n'avait aucun effet.
class RemoveUnusedColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :admin, :boolean
    remove_column :booking_settings, :vat_rate_percent, :decimal, precision: 5, scale: 2, default: 10.0, null: false
  end
end
