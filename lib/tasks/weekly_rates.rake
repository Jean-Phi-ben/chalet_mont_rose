namespace :weekly_rates do
  desc "Génère les tarifs hebdomadaires (samedi→samedi) jusqu'à fin décembre 2027"
  task seed: :environment do
    first_saturday = Date.new(2026, 5, 30)
    last_saturday  = Date.new(2027, 12, 25)

    created = 0
    updated = 0
    saturday = first_saturday

    while saturday <= last_saturday
      price_cents = WeeklyRatePricing.weekly_price_euros(saturday) * 100
      rate = WeeklyRate.find_or_initialize_by(week_start: saturday)
      new_record = rate.new_record?
      rate.price_cents = price_cents
      rate.save!
      new_record ? created += 1 : updated += 1
      saturday += 7
    end

    puts "Tarifs générés : #{created} créés, #{updated} mis à jour (#{first_saturday} → #{last_saturday})."
  end
end

# Grille tarifaire indicative — chalet de standing au Bettex (Saint-Gervais-les-Bains),
# domaine Évasion Mont-Blanc. Prix par semaine, en euros, selon la saisonnalité.
module WeeklyRatePricing
  module_function

  def weekly_price_euros(sat)
    m = sat.month
    d = sat.day
    fr = SchoolHolidays.france_for(sat)
    ch = SchoolHolidays.geneva_for(sat)

    # Noël / Nouvel An — pic absolu
    return 9200 if (m == 12 && d >= 18) || (m == 1 && d <= 2)

    # Vacances d'hiver (février → tout début mars) — pleine saison ski
    if m == 2 || (m == 3 && d <= 7)
      return (fr || ch) ? 8400 : 6200
    end

    case m
    when 1  then 5200                      # janvier — ski hors vacances
    when 3  then d <= 21 ? 4600 : 3800     # mars — ski déclinant
    when 4  then fr ? 3400 : 2800          # avril — vacances de printemps / intersaison
    when 5  then 2500                      # mai — basse saison
    when 6  then d >= 27 ? 3400 : 2800     # juin — remontée fin de mois
    when 7  then 5000                      # juillet — été
    when 8  then d <= 16 ? 5400 : 4400     # août — pic mi-août puis baisse
    when 9  then 2900                      # septembre — intersaison
    when 10 then fr ? 3600 : 2900          # octobre — Toussaint
    when 11 then fr ? 2600 : 2200          # novembre — basse saison
    when 12 then 4200                      # début décembre, avant Noël
    else 2800
    end
  end
end
