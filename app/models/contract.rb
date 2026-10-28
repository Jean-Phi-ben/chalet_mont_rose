require "bcrypt"

# Contrat de location avec signature électronique simple (SES).
# Workflow :
#   1. SendContractJob crée le Contract (statut :sent), snapshot du signataire
#      figé, token unique → email avec lien /reservations/:token/contract
#   2. Le client ouvre le lien, scroll jusqu'en bas, demande son OTP
#   3. Le mailer envoie un code 6 chiffres (hash bcrypt côté DB, 15 min de validité)
#   4. Le client saisit l'OTP + son tracé + coche d'acceptation → POST sign
#   5. À la signature : on horodate, on stocke IP + user agent + image PNG, et on
#      calcule le SHA-256 du document complet (texte + métadonnées). Le Contract
#      devient `signed` et `readonly`.
class Contract < ApplicationRecord
  belongs_to :booking
  validates :booking_id, uniqueness: true
  has_one_attached :signed_pdf

  has_secure_token :token, length: 32

  enum :status, { draft: 0, sent: 1, signed: 2, cancelled: 4 }, prefix: true

  OTP_LENGTH       = 6
  OTP_TTL          = 15.minutes
  OTP_MAX_ATTEMPTS = 5   # codes faux saisis, toutes générations confondues
  OTP_MAX_SENDS    = 5   # codes envoyés

  before_save :prevent_change_after_signature, if: -> { status_signed_was_persisted? && !destroyed? }

  # Génère et stocke un nouvel OTP. Renvoie le code en clair (à envoyer par
  # email immédiatement) — la DB ne conserve que le digest bcrypt.
  # Le compteur d'essais n'est PAS remis à zéro : renvoyer un code ne rouvre
  # pas 5 essais (sinon le verrou serait contournable à l'infini).
  def generate_otp!
    plain = SecureRandom.random_number(10**OTP_LENGTH).to_s.rjust(OTP_LENGTH, "0")
    update!(
      otp_digest:      BCrypt::Password.create(plain),
      otp_sent_at:     Time.current,
      otp_sends_count: otp_sends_count.to_i + 1
    )
    plain
  end

  # Déblocage par l'admin après verrouillage (compteurs remis à zéro, code purgé).
  def unlock_otp!
    update!(otp_attempts: 0, otp_sends_count: 0, otp_digest: nil, otp_sent_at: nil)
  end

  def otp_valid?(code)
    return false if otp_digest.blank? || otp_sent_at.blank?
    return false if otp_expired?
    BCrypt::Password.new(otp_digest).is_password?(code.to_s.strip)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def otp_expired?
    otp_sent_at.blank? || Time.current > (otp_sent_at + OTP_TTL)
  end

  def otp_locked?
    otp_attempts.to_i >= OTP_MAX_ATTEMPTS || otp_sends_count.to_i >= OTP_MAX_SENDS
  end

  # Un code valide est en circulation (envoyé et non expiré).
  def otp_pending?
    otp_digest.present? && !otp_expired?
  end

  def signable?
    status_sent? && !otp_locked?
  end

  # Calcule le hash SHA-256 figeant le document complet : contenu textuel,
  # snapshot du signataire, métadonnées de signature. Tout changement de l'un
  # de ces champs produit un hash différent → preuve d'intégrité.
  def compute_document_hash(canonical_text)
    payload = {
      booking_id:    booking_id,
      contract_text: canonical_text,
      signer:        { first_name: signer_first_name, last_name: signer_last_name,
                       email:      signer_email,       phone:    signer_phone,
                       address:    signer_address },
      signed_at:     signed_at&.utc&.iso8601, # en UTC : le hash ne dépend pas du fuseau de l'application
      signed_ip:     signed_ip,
      signed_ua:     signed_user_agent
    }
    Digest::SHA256.hexdigest(JSON.generate(payload))
  end

  def signer_full_name
    "#{signer_first_name} #{signer_last_name}".strip
  end

  # Texte du contrat à afficher / imprimer. Pour un contrat signé, c'est le texte
  # gelé à la signature (jamais recalculé) ; avant signature, le texte courant.
  def contract_text
    canonical_text.presence || ContractTemplate.canonical_text(booking, self)
  end

  # Le texte gelé reproduit-il exactement le hash enregistré à la signature ?
  def integrity_ok?
    status_signed? && canonical_text.present? && document_hash.present? &&
      compute_document_hash(canonical_text) == document_hash
  end

  private

  def status_signed_was_persisted?
    status_was == "signed"
  end

  # Une fois signé, le contrat est en lecture seule (sauf pour attacher le PDF).
  ALLOWED_CHANGES_AFTER_SIGNATURE = %w[updated_at signed_pdf_attachment].freeze

  def prevent_change_after_signature
    bad = changed_attributes.keys - ALLOWED_CHANGES_AFTER_SIGNATURE
    return if bad.empty?
    errors.add(:base, "Document signé — modification interdite (#{bad.join(', ')})")
    throw :abort
  end
end
