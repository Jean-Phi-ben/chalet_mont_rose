class BookingsController < ApplicationController
  allow_unauthenticated_access only: %i[calendar quote]

  def calendar
  end

  # Devis JSON pour le calendrier (sélection samedi → samedi).
  def quote
    render json: Pricing.quote(
      safe_date(params[:check_in]),
      safe_date(params[:check_out]),
      guests_count: params[:guests].to_i.clamp(1, 20)
    )
  end

  private

  def safe_date(value)
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end
end
