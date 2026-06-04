# Vacances scolaires utiles pour la tarification et l'affichage du calendrier.
#
# - France : union des zones A, B et C (toute semaine où au moins une zone est
#   en vacances => forte demande). Source : service-public.gouv.fr.
# - Suisse : canton de Genève (référence la plus proche du Bettex / Saint-Gervais ;
#   les vacances suisses sont cantonales). Source : ge.ch.
#
# Pour chaque période : `from` = premier jour de vacances, `to` = jour de reprise.
# Une semaine de location (samedi→samedi) n'est considérée « en vacances » que si
# le séjour tient ENTIÈREMENT dans la période (l'élève est libre toute la semaine) :
# la semaine qui commence au dernier samedi avant la reprise — donc avec des jours
# d'école — est exclue. Voir #full_week_within?.
# Les périodes « (est.) » de fin 2027 sont des estimations (calendrier 2027-2028
# non encore publié au Journal officiel au moment de la saisie).
class SchoolHolidays
  ALL_ZONES = %w[A B C].freeze

  # Toussaint, Noël et Été sont communs aux trois zones ; Hiver et Printemps
  # diffèrent par zone (A·B·C). On stocke chaque tranche par zone(s).
  FRANCE = [
    { label: "Toussaint", zones: ALL_ZONES, from: Date.new(2025, 10, 18), to: Date.new(2025, 11, 3) },
    { label: "Noël",      zones: ALL_ZONES, from: Date.new(2025, 12, 20), to: Date.new(2026, 1, 5) },
    { label: "Hiver",     zones: %w[A], from: Date.new(2026, 2, 7),  to: Date.new(2026, 2, 23) },
    { label: "Hiver",     zones: %w[B], from: Date.new(2026, 2, 14), to: Date.new(2026, 3, 2) },
    { label: "Hiver",     zones: %w[C], from: Date.new(2026, 2, 21), to: Date.new(2026, 3, 9) },
    { label: "Printemps", zones: %w[A], from: Date.new(2026, 4, 4),  to: Date.new(2026, 4, 20) },
    { label: "Printemps", zones: %w[B], from: Date.new(2026, 4, 11), to: Date.new(2026, 4, 27) },
    { label: "Printemps", zones: %w[C], from: Date.new(2026, 4, 18), to: Date.new(2026, 5, 4) },
    { label: "Été",       zones: ALL_ZONES, from: Date.new(2026, 7, 4),  to: Date.new(2026, 9, 1) },
    { label: "Toussaint", zones: ALL_ZONES, from: Date.new(2026, 10, 17), to: Date.new(2026, 11, 2) },
    { label: "Noël",      zones: ALL_ZONES, from: Date.new(2026, 12, 19), to: Date.new(2027, 1, 4) },
    { label: "Hiver",     zones: %w[C], from: Date.new(2027, 2, 6),  to: Date.new(2027, 2, 22) },
    { label: "Hiver",     zones: %w[A], from: Date.new(2027, 2, 13), to: Date.new(2027, 3, 1) },
    { label: "Hiver",     zones: %w[B], from: Date.new(2027, 2, 20), to: Date.new(2027, 3, 8) },
    { label: "Printemps", zones: %w[C], from: Date.new(2027, 4, 3),  to: Date.new(2027, 4, 19) },
    { label: "Printemps", zones: %w[A], from: Date.new(2027, 4, 10), to: Date.new(2027, 4, 26) },
    { label: "Printemps", zones: %w[B], from: Date.new(2027, 4, 17), to: Date.new(2027, 5, 3) },
    { label: "Été",       zones: ALL_ZONES, from: Date.new(2027, 7, 3),  to: Date.new(2027, 9, 1) },
    { label: "Toussaint (est.)", zones: ALL_ZONES, from: Date.new(2027, 10, 23), to: Date.new(2027, 11, 8) },
    { label: "Noël (est.)",      zones: ALL_ZONES, from: Date.new(2027, 12, 18), to: Date.new(2028, 1, 3) }
  ].freeze

  # `to` = jour de reprise (lundi suivant le dernier jour de vacances).
  GENEVA = [
    { label: "Automne", from: Date.new(2025, 10, 20), to: Date.new(2025, 10, 27) },
    { label: "Noël",    from: Date.new(2025, 12, 22), to: Date.new(2026, 1, 5) },
    { label: "Pâques",  from: Date.new(2026, 4, 3),   to: Date.new(2026, 4, 20) },
    { label: "Été",     from: Date.new(2026, 6, 29),  to: Date.new(2026, 8, 17) },
    { label: "Automne", from: Date.new(2026, 10, 19), to: Date.new(2026, 10, 26) },
    { label: "Noël",    from: Date.new(2026, 12, 24), to: Date.new(2027, 1, 11) },
    { label: "Février", from: Date.new(2027, 2, 15),  to: Date.new(2027, 2, 22) },
    { label: "Pâques",  from: Date.new(2027, 3, 26),  to: Date.new(2027, 4, 12) },
    { label: "Été",     from: Date.new(2027, 7, 5),   to: Date.new(2027, 8, 23) },
    { label: "Automne (est.)", from: Date.new(2027, 10, 18), to: Date.new(2027, 10, 25) },
    { label: "Noël (est.)",    from: Date.new(2027, 12, 24), to: Date.new(2028, 1, 10) }
  ].freeze

  # Vacances FR pour la semaine de location samedi→samedi (entièrement comprise), ou nil.
  # Renvoie { label:, zones: [...] } où zones liste les zones concernées (A·B·C).
  def self.france_for(week_start)
    return nil if week_start.nil?

    matches = FRANCE.select { |p| full_week_within?(p, week_start) }
    return nil if matches.empty?

    { label: matches.first[:label], zones: matches.flat_map { |m| m[:zones] }.uniq.sort }
  end

  # Vacances genevoises pour la semaine de location (entièrement comprise), ou nil.
  def self.geneva_for(week_start)
    return nil if week_start.nil?

    GENEVA.find { |p| full_week_within?(p, week_start) }
  end

  # La semaine samedi→samedi tient-elle entièrement dans la période ?
  # lundi de la semaine (samedi+2) >= début ET samedi de départ (samedi+7) <= reprise.
  def self.full_week_within?(period, week_start)
    monday   = week_start + 2
    checkout = week_start + 7
    monday >= period[:from] && checkout <= period[:to]
  end
end
