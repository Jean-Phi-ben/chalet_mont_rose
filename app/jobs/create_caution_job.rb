# Crée la demande de caution Swikly pour un booking confirmé.
# Idempotent : une demande déjà en attente avec son lien n'est pas recréée
# (sinon chaque rappel manuel multiplierait les liens actifs). `force: true`
# pour en émettre une nouvelle malgré tout.
class CreateCautionJob < ApplicationJob
  queue_as :default

  def perform(booking, force: false)
    caution = booking.caution
    # Une caution déjà acceptée/capturée/libérée ne doit pas être réémise.
    return if caution && !caution.status_pending?
    return if caution&.deposit_url.present? && !force

    caution ||= booking.build_caution
    result    = SwiklyProvider.create_request(booking)

    caution.update!(
      provider_request_id: result.provider_request_id,
      deposit_url:         result.deposit_url,
      amount_cents:        Caution.amount_for(booking),
      status:              :pending,
      requested_at:        Time.current
    )
  end
end
