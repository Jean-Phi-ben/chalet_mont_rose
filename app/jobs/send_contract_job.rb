# Crée (ou re-crée) le contrat de signature électronique simple (SES) lié à
# un booking confirmé, fige le snapshot du signataire et envoie au client
# l'email d'invitation à signer (lien unique avec token).
class SendContractJob < ApplicationJob
  queue_as :default

  def perform(booking)
    return if booking.contract&.status_signed?

    contract = booking.contract || booking.build_contract
    contract.assign_attributes(
      status:             :sent,
      sent_at:            Time.current,
      signer_first_name:  booking.first_name,
      signer_last_name:   booking.last_name,
      signer_email:       booking.email,
      signer_phone:       booking.phone,
      signer_address:     booking.client&.address || booking.address
    )
    # has_secure_token génère token automatiquement à la première sauvegarde.
    contract.save!

    # Pas d'email d'invitation séparé : le lien de signature est inclus
    # directement dans l'email de confirmation (BookingMailer#confirmation)
    # envoyé par le contrôleur juste après.
  end
end
