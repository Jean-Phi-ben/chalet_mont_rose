module Beds24
  # Miroir des réservations du site dans Beds24 (lot 2).
  #
  # - Réservation confirmée  → réservation Beds24 `confirmed` (créée puis modifiée par son id).
  # - Réservation annulée, refusée ou supprimée → la réservation Beds24 passe `cancelled`.
  # - Semaine « Famille »     → blocage Beds24 `black` ; décochée → `cancelled`.
  # L'identifiant Beds24 est mémorisé dans `beds24_booking_id` ; `allowWebhooks: false`
  # évite que Beds24 nous renvoie nos propres réservations par webhook (lot 3).
  class BookingSync
    REFERER = "Site chaletmontrose.fr".freeze

    def initialize(client: Client.new, room_id: Config.room_id)
      @client = client
      @room_id = room_id
    end

    # Pousse l'état courant d'une réservation ou d'une semaine tarifaire. Renvoie l'id Beds24, ou nil
    # s'il n'y avait rien à envoyer (réservation jamais confirmée, semaine jamais bloquée).
    def push(record)
      payload = payload_for(record)
      return nil if payload.nil?

      id = upsert(record.beds24_booking_id, payload)
      record.update_column(:beds24_booking_id, id) if id && record.beds24_booking_id != id
      id
    end

    # Annule dans Beds24 une réservation dont l'enregistrement local a disparu.
    def cancel(beds24_booking_id)
      upsert(beds24_booking_id, status: "cancelled")
    end

    def payload_for(record)
      case record
      when Booking    then booking_payload(record)
      when WeeklyRate then family_payload(record)
      else raise ArgumentError, "enregistrement non synchronisable : #{record.class}"
      end
    end

    private

    def booking_payload(booking)
      if booking.confirmed?
        {
          roomId: @room_id, status: "confirmed",
          arrival: booking.check_in.iso8601, departure: booking.check_out.iso8601,
          numAdult: [ booking.guests_count.to_i, 1 ].max,
          firstName: booking.first_name, lastName: booking.last_name,
          email: booking.email, phone: booking.phone.presence,
          price: booking.total_price_cents.to_i / 100.0,
          referer: REFERER, apiReference: "cmr-booking-#{booking.id}",
          comments: "Réservation directe n°#{booking.id}, gérée sur chaletmontrose.fr (contrat, factures, caution).",
          allowWebhooks: false
        }.compact
      elsif booking.beds24_booking_id
        { status: "cancelled", allowWebhooks: false }
      end
    end

    def family_payload(rate)
      if rate.blocked?
        {
          roomId: @room_id, status: "black",
          arrival: rate.week_start.iso8601, departure: rate.week_end.iso8601,
          numAdult: 1, firstName: "Famille", lastName: "Chalet Mont Rose",
          referer: REFERER, apiReference: "cmr-family-#{rate.week_start.iso8601}",
          comments: "Semaine réservée par la famille (sans réservation ni facture).",
          allowWebhooks: false
        }
      elsif rate.beds24_booking_id
        { status: "cancelled", allowWebhooks: false }
      end
    end

    # Création (sans id) ou modification (avec id). Renvoie l'id Beds24.
    def upsert(beds24_booking_id, payload)
      body = beds24_booking_id ? payload.merge(id: beds24_booking_id) : payload
      result = Array(@client.post_bookings([ body ])).first
      raise Client::Error, "réservation refusée par Beds24 : #{Client.error_message(result)}" unless result.is_a?(Hash) && result["success"]

      returned = result["new"] || result["modified"] || result
      (returned.is_a?(Hash) && returned["id"]) || beds24_booking_id
    end
  end
end
