class AddBreakdownToBookings < ActiveRecord::Migration[8.1]
  def up
    add_column :bookings, :accommodation_cents, :integer
    add_column :bookings, :cleaning_fee_cents,  :integer, default: 0, null: false
    add_column :bookings, :tourist_tax_cents,   :integer, default: 0, null: false

    # Pour l'existant : on suppose que le total enregistré correspondait à l'hébergement.
    execute "UPDATE bookings SET accommodation_cents = total_price_cents WHERE accommodation_cents IS NULL"

    change_column_default :bookings, :accommodation_cents, 0
    change_column_null    :bookings, :accommodation_cents, false, 0
  end

  def down
    remove_column :bookings, :accommodation_cents
    remove_column :bookings, :cleaning_fee_cents
    remove_column :bookings, :tourist_tax_cents
  end
end
