module Beds24
  # Pousse vers Beds24 l'état d'une réservation (confirmée / annulée) ou d'une semaine
  # tarifaire (bloquée « Famille » / libérée). Déclenché par les rappels des modèles.
  class PushBookingJob < ApplicationJob
    queue_as :default
    retry_on Beds24::Client::Error, wait: :polynomially_longer, attempts: 5

    def perform(record)
      return unless Config.enabled?

      id = BookingSync.new.push(record)
      Rails.logger.info("Beds24 : #{record.class} ##{record.id} synchronisée (réservation Beds24 #{id || 'aucune'})")
    end
  end
end
