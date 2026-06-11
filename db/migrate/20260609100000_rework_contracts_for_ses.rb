# Refonte du modèle Contract : abandon de Dropbox Sign, passage à un système
# de Signature Électronique Simple (SES) maison conforme à l'esprit eIDAS :
#   - lien sécurisé (token unique)
#   - 2FA par code OTP envoyé par email (15 min de validité)
#   - capture du tracé de signature (PNG base64)
#   - dossier de preuves (IP, user agent, horodatage, hash SHA-256 du document)
class ReworkContractsForSes < ActiveRecord::Migration[8.1]
  def change
    # Anciennes colonnes Dropbox Sign à retirer.
    remove_column :contracts, :provider_request_id,   :string
    remove_column :contracts, :provider_signature_id, :string
    remove_column :contracts, :sign_url,              :string
    remove_column :contracts, :declined_at,           :datetime
    remove_column :contracts, :decline_reason,        :string

    # SES : accès et OTP.
    add_column :contracts, :token,                :string, null: false, default: ""
    add_column :contracts, :otp_digest,           :string                # bcrypt
    add_column :contracts, :otp_sent_at,          :datetime
    add_column :contracts, :otp_attempts,         :integer, null: false, default: 0
    add_index  :contracts, :token, unique: true

    # Snapshot du signataire (figé au moment de l'émission, non modifiable).
    add_column :contracts, :signer_first_name, :string
    add_column :contracts, :signer_last_name,  :string
    add_column :contracts, :signer_email,      :string
    add_column :contracts, :signer_phone,      :string
    add_column :contracts, :signer_address,    :string

    # Dossier de preuves.
    add_column :contracts, :signed_ip,         :string
    add_column :contracts, :signed_user_agent, :text
    add_column :contracts, :signature_image,   :text     # base64 PNG du tracé
    add_column :contracts, :document_hash,     :string   # SHA-256 figé après signature
  end
end
