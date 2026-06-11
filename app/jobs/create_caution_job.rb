# Crée (ou re-crée) la demande de caution Swikly pour un booking confirmé.
class CreateCautionJob < ApplicationJob
  queue_as :default

  def perform(booking)
    # Une caution déjà acceptée/capturée/libérée ne doit pas être réémise.
    return if booking.caution && !booking.caution.status_pending?

    caution = booking.caution || booking.build_caution
    result  = SwiklyProvider.create_request(booking)

    caution.update!(
      provider_request_id: result.provider_request_id,
      deposit_url:         result.deposit_url,
      amount_cents:        caution_amount_cents(booking),
      status:              :pending,
      requested_at:        Time.current
    )
  end

  private

  def caution_amount_cents(booking)
    explicit = ENV["CAUTION_AMOUNT"].to_i
    return explicit * 100 if explicit.positive?

    # Fallback : 30 % du séjour, dans une fourchette 500–2000 €.
    ((booking.total_price_cents.to_i * 0.30).round).clamp(50_000, 200_000)
  end
end
