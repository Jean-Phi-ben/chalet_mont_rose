class AddVatRate < ActiveRecord::Migration[8.1]
  def change
    # Taux de TVA configurable globalement, snapshoté sur chaque réservation.
    # Stocké en pourcentage avec 2 décimales (ex : 10.00 pour 10 %).
    add_column :booking_settings, :vat_rate_percent, :decimal, precision: 5, scale: 2, default: 10.0, null: false
    add_column :bookings,         :vat_rate_percent, :decimal, precision: 5, scale: 2, default: 10.0, null: false
  end
end
