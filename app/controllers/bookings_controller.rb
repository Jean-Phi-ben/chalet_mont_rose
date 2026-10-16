class BookingsController < ApplicationController
  allow_unauthenticated_access only: :quote

  # Devis JSON pour le calendrier (sélection samedi → samedi).
  def quote
    render json: Pricing.quote(
      safe_date(params[:check_in]),
      safe_date(params[:check_out]),
      guests_count: params[:guests].to_i.clamp(1, 12),
      earliest_check_in: Date.current
    )
  end

  private

  def safe_date(value)
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end
end
