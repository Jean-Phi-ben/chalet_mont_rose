# Synchronisation avec Beds24 (channel manager → Airbnb).
#
# Lot 1 : le site est maître des tarifs et des restrictions. Chaque nuit (et après toute
# modification de tarif ou de réservation confirmée), Beds24::PushCalendarJob pousse vers
# Beds24 le calendrier de la chambre : prix direct (price1), prix Airbnb majoré (price2),
# séjour de 7 nuits minimum, arrivée le samedi, nuits occupées (réservations confirmées
# et semaines « Famille »).
#
# Réglages : voir Beds24::Config (variables BEDS24_*). Sans BEDS24_REFRESH_TOKEN et
# BEDS24_ROOM_ID, rien n'est envoyé.
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
end
