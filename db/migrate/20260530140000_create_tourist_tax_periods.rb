class CreateTouristTaxPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :tourist_tax_periods do |t|
      t.string  :season, null: false               # "summer" (mai-septembre) ou "winter" (octobre-avril)
      t.integer :year,   null: false               # année de début de la période
      t.boolean :paid,   null: false, default: false
      t.date    :paid_on
      t.timestamps
    end
    add_index :tourist_tax_periods, %i[season year], unique: true
  end
end
