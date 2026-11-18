module Beds24
  # Construit les plages à envoyer à POST /inventory/rooms/calendar à partir des tarifs
  # du site : prix direct (price1), prix Airbnb (price2), séjour minimum et maximum, et
  # jour d'arrivée (le samedi seulement). Une entrée par nuit, puis les nuits consécutives
  # identiques sont fusionnées : une semaine donne le samedi (`none`) puis dimanche → vendredi
  # (`noCheckIn`). Les nuits occupées ne passent pas par le calendrier mais par les
  # réservations miroir (Beds24::BookingSync) : les écrire ici aussi ferait compter les
  # nuits deux fois côté Beds24.
  class CalendarPlanner
    Entry = Struct.new(:from, :to, :price1, :price2, :minStay, :maxStay, :numAvail, :override, keyword_init: true) do
      def same_values?(other)
        to_h.except(:from, :to) == other.to_h.except(:from, :to)
      end

      # Corps JSON attendu par Beds24 (dates ISO, clés en camelCase).
      def payload
        to_h.merge(from: from.iso8601, to: to.iso8601)
      end
    end

    def initialize(rates: WeeklyRate.upcoming.ordered, from: Date.current.beginning_of_week(:saturday))
      @rates = rates.to_a.select { |r| r.week_start >= from }
    end

    def entries
      nightly = @rates.flat_map do |rate|
        price1 = AirbnbPricing.direct_nightly_euros(rate.price_cents)
        price2 = AirbnbPricing.nightly_euros(rate.price_cents)
        (rate.week_start...rate.week_end).map do |night|
          Entry.new(from: night, to: night, price1: price1, price2: price2,
                    minStay: Config.min_stay_nights, maxStay: Config.max_stay_nights,
                    numAvail: 1, override: night.saturday? ? "none" : "noCheckIn")
        end
      end
      merge(nightly)
    end

    def first_night = @rates.first&.week_start
    def last_night  = @rates.last && @rates.last.week_end - 1

    private

    def merge(nightly)
      nightly.each_with_object([]) do |entry, acc|
        last = acc.last
        if last && last.same_values?(entry) && last.to + 1 == entry.from
          last.to = entry.to
        else
          acc << entry
        end
      end
    end
  end
end
