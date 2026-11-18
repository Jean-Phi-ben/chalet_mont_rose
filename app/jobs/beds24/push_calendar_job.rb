module Beds24
  # Pousse vers Beds24 le calendrier complet (prix, restrictions, nuits occupées) de la
  # semaine en cours jusqu'à la dernière semaine tarifée. Quotidien (recurring.yml) et
  # après toute modification de tarif ou de réservation confirmée (Beds24.schedule_calendar_push).
  class PushCalendarJob < ApplicationJob
    queue_as :default
    retry_on Beds24::Client::Error, wait: :polynomially_longer, attempts: 3

    def perform
      Rails.cache.delete(Beds24::DEBOUNCE_KEY)
      return unless Config.enabled?

      planner = CalendarPlanner.new
      entries = planner.entries
      if entries.empty?
        Rails.logger.info("Beds24 : aucun tarif à venir, calendrier non poussé")
        return
      end

      Client.new.write_calendar(room_id: Config.room_id, entries: entries.map(&:payload))
      Rails.logger.info("Beds24 : calendrier poussé, #{entries.size} plages du #{planner.first_night} au #{planner.last_night}")
    end
  end
end
