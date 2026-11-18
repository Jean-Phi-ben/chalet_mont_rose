# Synchronisation avec Beds24 (channel manager → Airbnb). Le site est maître.
#
# Lot 1 — calendrier : chaque nuit (et après toute modification de tarif), Beds24::PushCalendarJob
#   pousse prix direct (price1), prix Airbnb majoré (price2), 7 nuits minimum et arrivée le samedi.
# Lot 2 — réservations : chaque réservation confirmée et chaque semaine « Famille » a une
#   réservation miroir dans Beds24 (Beds24::BookingSync), créée, modifiée ou annulée par
#   Beds24::PushBookingJob ; c'est elle qui ferme les nuits sur Airbnb.
#
# Réglages : Beds24::Config (variables BEDS24_*). Sans BEDS24_REFRESH_TOKEN et BEDS24_ROOM_ID,
# rien n'est envoyé.
module Beds24
  DEBOUNCE_KEY = "beds24/calendar_push_scheduled".freeze
  DEBOUNCE     = 2.minutes

  # Planifie une poussée du calendrier, au plus une toutes les deux minutes : une édition
  # en lot de 80 tarifs ne doit pas déclencher 80 appels à l'API.
  def self.schedule_calendar_push
    return false unless Config.enabled?
    return false unless Rails.cache.write(DEBOUNCE_KEY, true, expires_in: DEBOUNCE, unless_exist: true)

    PushCalendarJob.set(wait: DEBOUNCE).perform_later
    true
  end

  # Planifie la synchronisation d'une réservation ou d'une semaine tarifaire.
  def self.schedule_booking_push(record)
    return false unless Config.enabled?

    PushBookingJob.perform_later(record)
    true
  end

  # Planifie l'annulation d'une réservation miroir dont l'enregistrement local a disparu.
  def self.schedule_booking_cancel(beds24_booking_id)
    return false unless Config.enabled? && beds24_booking_id.present?

    CancelBookingJob.perform_later(beds24_booking_id)
    true
  end
end
