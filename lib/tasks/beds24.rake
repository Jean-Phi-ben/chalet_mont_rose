namespace :beds24 do
  desc "Échange un code d'invitation Beds24 contre un refreshToken (à placer dans BEDS24_REFRESH_TOKEN)"
  task :setup, [ :invite_code ] => :environment do |_, args|
    code = args[:invite_code].presence or abort "Usage : bin/rails \"beds24:setup[CODE_INVITATION]\""
    result = Beds24::Client.setup(code)
    puts "refreshToken obtenu. Ajoutez cette ligne à votre fichier d'environnement (.env / ~/.chalet_env) :"
    puts
    puts "BEDS24_REFRESH_TOKEN=#{result.fetch('refreshToken')}"
    puts
    puts "Puis `bin/rails beds24:properties` pour trouver BEDS24_ROOM_ID."
  end

  desc "Liste les propriétés et chambres du compte Beds24 (pour BEDS24_ROOM_ID)"
  task properties: :environment do
    Beds24::Client.new.properties.each do |property|
      puts "Propriété #{property['id']} — #{property['name']}"
      Array(property["roomTypes"]).each { |room| puts "  chambre #{room['id']} — #{room['name']}" }
    end
  end

  desc "Pousse le calendrier (prix, séjour minimum, arrivée le samedi) vers Beds24. DRY_RUN=1 : affiche sans envoyer"
  task push_calendar: :environment do
    planner = Beds24::CalendarPlanner.new
    entries = planner.entries
    abort "Aucun tarif à venir." if entries.empty?

    coef = Beds24::AirbnbPricing.coefficient
    puts "Mode Airbnb #{Beds24::Config.airbnb_mode} : coefficient #{coef.round(4)}, ménage #{planner.cleaning_week_cents / 100} € par semaine inclus"
    puts format("%-10s → %-10s %7s %7s %4s %4s %4s  %s", "du", "au", "direct", "airbnb", "min", "max", "dispo", "override")
    entries.each do |e|
      puts format("%s → %s %7d %7d %4d %4d %5d  %s", e.from, e.to, e.price1, e.price2, e.minStay, e.maxStay, e.numAvail, e.override)
    end
    puts "#{entries.size} plages du #{planner.first_night} au #{planner.last_night}."

    if ENV["DRY_RUN"].present?
      puts "Simulation : rien n'a été envoyé."
    elsif !Beds24::Config.enabled?
      abort "Beds24 non configuré (BEDS24_REFRESH_TOKEN / BEDS24_ROOM_ID) : rien n'a été envoyé."
    else
      Beds24::Client.new.write_calendar(room_id: Beds24::Config.room_id, entries: entries.map(&:payload))
      puts "Envoyé à Beds24 (chambre #{Beds24::Config.room_id})."
    end
  end

  desc "Pousse vers Beds24 toutes les réservations confirmées à venir et les semaines Famille. DRY_RUN=1 : affiche sans envoyer"
  task push_bookings: :environment do
    today = Date.current
    records = Booking.confirmed.where("check_out >= ?", today).order(:check_in).to_a +
              WeeklyRate.blocked.where("week_start + 7 >= ?", today).ordered.to_a
    abort "Rien à pousser : aucune réservation confirmée ni semaine Famille à venir." if records.empty?

    sync = Beds24::BookingSync.new(client: ENV["DRY_RUN"].present? ? nil : Beds24::Client.new)
    records.each do |record|
      payload = sync.payload_for(record)
      label = record.is_a?(Booking) ? "réservation ##{record.id}" : "semaine Famille #{record.week_start}"
      if ENV["DRY_RUN"].present?
        puts "#{label} (Beds24 #{record.beds24_booking_id || 'nouvelle'}) : #{payload.to_json}"
      else
        id = sync.push(record)
        puts "#{label} → Beds24 #{id}"
      end
    end
    puts ENV["DRY_RUN"].present? ? "Simulation : rien n'a été envoyé." : "#{records.size} enregistrement(s) synchronisé(s)."
  end

  desc "Liste les réservations connues de Beds24 pour la chambre (toutes origines, à partir d'aujourd'hui)"
  task bookings: :environment do
    Beds24::Client.new.bookings(room_id: Beds24::Config.room_id, from: Date.current).each do |b|
      puts format("%-8s %-10s %s → %s  %-28s %-24s api=%s",
                  b["id"], b["status"], b["arrival"], b["departure"], "#{b['firstName']} #{b['lastName']}", b["referer"], b["apiReference"])
    end
  end

  desc "Affiche le calendrier tel que Beds24 le connaît (vérification après une poussée)"
  task calendar: :environment do
    planner = Beds24::CalendarPlanner.new
    abort "Aucun tarif à venir." if planner.first_night.nil?

    Beds24::Client.new.calendar(room_id: Beds24::Config.room_id, from: planner.first_night, to: planner.last_night).each do |room|
      Array(room["calendar"]).each do |day|
        puts format("%s → %s  price1=%s price2=%s minStay=%s maxStay=%s numAvail=%s override=%s",
                    day["from"], day["to"], day["price1"], day["price2"], day["minStay"], day["maxStay"], day["numAvail"], day["override"])
      end
    end
  end
end
