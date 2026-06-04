class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.string  :number, null: false
      t.date    :issued_on, null: false
      t.integer :total_cents, null: false
      t.integer :deposit_cents, null: false
      t.integer :balance_cents, null: false
      t.integer :deposit_status, null: false, default: 0
      t.date    :deposit_received_on
      t.integer :balance_status, null: false, default: 0
      t.date    :balance_received_on
      t.datetime :balance_reminder_sent_at
      t.datetime :forwarded_to_dext_at
      t.timestamps
    end

    add_index :invoices, :number, unique: true
  end
end
