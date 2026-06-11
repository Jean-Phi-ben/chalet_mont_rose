class CreateCautions < ActiveRecord::Migration[8.1]
  def change
    create_table :cautions do |t|
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.string  :provider_request_id   # id Swik (Swikly)
      t.string  :deposit_url           # lien que le client utilise pour déposer sa caution
      t.datetime :requested_at
      t.datetime :accepted_at
      t.datetime :released_at
      t.datetime :captured_at
      t.string   :decline_reason
      t.timestamps
    end
  end
end
