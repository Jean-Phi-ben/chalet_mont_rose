class PagesController < ApplicationController
  allow_unauthenticated_access only: :home

  def home
    cheapest_cents = WeeklyRate.single_week_bookable.minimum(:price_cents)
    @cheapest_week_price = cheapest_cents && (cheapest_cents / 100.0).round
  end
end
