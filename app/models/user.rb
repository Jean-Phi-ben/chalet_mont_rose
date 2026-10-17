class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  PASSWORD_MIN_LENGTH = 10

  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_nil: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Lien de vérification de l'adresse (valable 2 jours, invalidé si l'adresse change).
  generates_token_for :email_verification, expires_in: 2.days do
    email_address
  end

  # Le statut admin dépend uniquement de la liste blanche d'adresses autorisées
  # (ADMIN_EMAILS), pas d'un drapeau en base. Utilisé par Pundit et le back-office.
  def admin?
    AdminAccess.authorized?(email_address)
  end

  # Adresse prouvée : lien de vérification cliqué, connexion Google (email vérifié
  # par Google) ou mot de passe réinitialisé depuis la boîte email.
  def verified?
    email_verified_at.present?
  end

  def verify!
    update!(email_verified_at: Time.current) unless verified?
  end
end
