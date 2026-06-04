class CreateWeeklyRates < ActiveRecord::Migration[8.1]
  def change
    create_table :weekly_rates do |t|
      t.date :week_start, null: false
      t.integer :price_cents, null: false
      t.integer :min_weeks, null: false, default: 1
      t.string :note

      t.timestamps
    end

    add_index :weekly_rates, :week_start, unique: true
  end
end
