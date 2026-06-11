class CreateContracts < ActiveRecord::Migration[8.1]
  def change
    create_table :contracts do |t|
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.string  :provider_request_id   # signature_request_id Dropbox Sign
      t.string  :provider_signature_id # id de la signature côté client
      t.string  :sign_url              # URL embarquée (expirable, on la régénère si besoin)
      t.datetime :sent_at
      t.datetime :signed_at
      t.datetime :declined_at
      t.string   :decline_reason
      t.timestamps
    end
  end
end
