module Beds24
  # Annule dans Beds24 une réservation miroir dont l'enregistrement local a été supprimé
  # (réservation confirmée supprimée, semaine tarifaire bloquée supprimée).
  class CancelBookingJob < ApplicationJob
    queue_as :default
    retry_on Beds24::Client::Error, wait: :polynomially_longer, attempts: 5

    def perform(beds24_booking_id)
      return unless Config.enabled?

      BookingSync.new.cancel(beds24_booking_id)
      Rails.logger.info("Beds24 : réservation #{beds24_booking_id} annulée (enregistrement local supprimé)")
    end
  end
end
