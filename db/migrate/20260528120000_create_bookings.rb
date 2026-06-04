class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.integer :guests_count
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :message
      t.integer :status, null: false, default: 0
      t.integer :total_price_cents
      t.integer :deposit_cents
      t.string :token, null: false
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :bookings, :token, unique: true
    add_index :bookings, :status
    add_index :bookings, :check_in
  end
end
