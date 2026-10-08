# Espace client — cloisonné de l'admin.
# Exige une session valide (le before_action :require_authentication de
# ApplicationController s'applique par défaut). N'expose JAMAIS de contenu admin,
# même si l'utilisateur connecté est administrateur.
class Account::BaseController < ApplicationController
  layout "account"

  private

  def current_email
    Current.user.email_address.to_s.downcase
  end
  helper_method :current_email

  # Réservations du client : rattachées par email (insensible à la casse).
  def my_bookings
    Booking.where("lower(email) = ?", current_email)
  end

  # Fiche profil du client (peut être nil si jamais réservé / pas encore créée).
  def my_client
    @my_client ||= Client.find_by("lower(email) = ?", current_email)
  end
  helper_method :my_client
end
