# Données de la page d'accueil, partagées entre PagesController#home et le
# re-rendu de l'accueil après une demande de réservation invalide.
module HomePage
  extend ActiveSupport::Concern

  private

  def prepare_home
    cheapest_cents = WeeklyRate.single_week_bookable.minimum(:price_cents)
    @cheapest_week_price = cheapest_cents && (cheapest_cents / 100.0).round
    @booking ||= Booking.new(guests_count: 2)
  end
end
