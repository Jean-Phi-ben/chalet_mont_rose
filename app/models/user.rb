class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Le statut admin dépend uniquement de la liste blanche d'adresses autorisées
  # (ADMIN_EMAILS), pas d'un drapeau en base. Utilisé par Pundit et le back-office.
  def admin?
    AdminAccess.authorized?(email_address)
  end
end
