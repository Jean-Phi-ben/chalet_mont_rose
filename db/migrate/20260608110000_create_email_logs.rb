class CreateEmailLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :email_logs do |t|
      t.references :booking, null: true, foreign_key: true
      t.string  :mailer,    null: false
      t.string  :action,    null: false
      t.string  :to_addresses, null: false   # CSV des destinataires
      t.string  :cc_addresses
      t.string  :bcc_addresses
      t.string  :from_address
      t.string  :subject
      t.datetime :sent_at, null: false
      t.string :message_id    # Message-ID RFC 822 pour traçabilité
      t.timestamps
    end
    add_index :email_logs, :sent_at
  end
end
