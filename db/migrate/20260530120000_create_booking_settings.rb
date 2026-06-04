class CreateBookingSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :booking_settings do |t|
      t.integer :cleaning_fee_cents, default: 40_000, null: false
      t.integer :tourist_tax_per_person_per_night_cents, default: 260, null: false
      t.timestamps
    end
  end
end
