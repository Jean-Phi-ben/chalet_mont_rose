# Export Excel de la grille des tarifs hebdomadaires (back-office).
#
# Onglet « Grille »  : une ligne par semaine (samedi → samedi) avec prix, vacances
#                      scolaires FR / Genève, semaine réservée famille, note.
# Onglet « Saisons » : les périodes tarifaires (semaines consécutives au même prix
#                      dans la même saison), puis une synthèse par saison.
class WeeklyRatesExport
  NIGHTS_PER_WEEK = 7

  Period = Struct.new(:season, :from, :to, :price_cents, :weeks, :blocked, :holidays, :notes, keyword_init: true)

  def initialize(rates)
    @rates = rates.to_a
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true # requis pour Numbers / LibreOffice anciens
    build_styles(package.workbook)
    add_grid_sheet(package.workbook)
    add_seasons_sheet(package.workbook)
    package.to_stream.read
  end

  # Saison « touristique » d'une semaine, utilisée pour nommer et grouper les périodes.
  def self.season_for(week_start)
    m, d = week_start.month, week_start.day
    return "Noël et Nouvel An" if (m == 12 && d >= 18) || (m == 1 && d <= 2)

    case m
    when 12, 1, 2, 3, 4 then "Hiver"
    when 5, 6           then "Printemps"
    when 7, 8           then "Été"
    else                     "Automne"
    end
  end

  # Semaines consécutives au même prix et dans la même saison → une période.
  def periods
    @rates.each_with_object([]) do |rate, acc|
      season = self.class.season_for(rate.week_start)
      last   = acc.last
      if last && last.price_cents == rate.price_cents && last.season == season && last.to == rate.week_start
        last.to = rate.week_start + NIGHTS_PER_WEEK
        last.weeks += 1
      else
        acc << Period.new(season: season, from: rate.week_start, to: rate.week_start + NIGHTS_PER_WEEK,
                          price_cents: rate.price_cents, weeks: 1, blocked: 0, holidays: [], notes: [])
        last = acc.last
      end
      last.blocked += 1 if rate.blocked?
      last.holidays.concat(holiday_entries(rate))
      last.notes << rate.note if rate.note.present?
    end
  end

  # « FR Hiver (A·B·C) ; CH Février » : les zones FR d'un même libellé sont fusionnées.
  def self.holiday_text(entries)
    entries.group_by { |country, label, _| [ country, label ] }.map do |(country, label), items|
      zones = items.flat_map { |_, _, z| z || [] }.uniq.sort
      zones.empty? ? "#{country} #{label}" : "#{country} #{label} (#{zones.join('·')})"
    end.join(" ; ").presence
  end

  private

  def build_styles(workbook)
    s = workbook.styles
    @st = {
      header:  s.add_style(b: true, fg_color: "FFFFFF", bg_color: "1C1917", alignment: { horizontal: :center, vertical: :center, wrap_text: true }),
      title:   s.add_style(b: true, sz: 14),
      text:    s.add_style(alignment: { vertical: :center }),
      wrap:    s.add_style(alignment: { vertical: :center, wrap_text: true }),
      int:     s.add_style(num_fmt: 1, alignment: { horizontal: :center, vertical: :center }),
      date:    s.add_style(format_code: "dd/mm/yyyy", alignment: { horizontal: :center, vertical: :center }),
      euro:    s.add_style(format_code: '#,##0 "€"', alignment: { horizontal: :right, vertical: :center }),
      euro_dec: s.add_style(format_code: '#,##0.00 "€"', alignment: { horizontal: :right, vertical: :center }),
      blocked: s.add_style(bg_color: "E7E5E4", alignment: { vertical: :center }),
      blocked_euro: s.add_style(bg_color: "E7E5E4", format_code: '#,##0 "€"', alignment: { horizontal: :right, vertical: :center }),
      blocked_date: s.add_style(bg_color: "E7E5E4", format_code: "dd/mm/yyyy", alignment: { horizontal: :center, vertical: :center }),
      blocked_int:  s.add_style(bg_color: "E7E5E4", num_fmt: 1, alignment: { horizontal: :center, vertical: :center }),
      blocked_euro_dec: s.add_style(bg_color: "E7E5E4", format_code: '#,##0.00 "€"', alignment: { horizontal: :right, vertical: :center })
    }
  end

  def add_grid_sheet(workbook)
    workbook.add_worksheet(name: "Grille") do |sheet|
      sheet.add_row [ "Sem. n°", "Arrivée (samedi)", "Départ (samedi)", "Saison", "Prix / semaine", "Prix / nuit",
                      "Vacances FR", "Vacances Genève", "Famille", "Note" ], style: @st[:header], height: 30

      @rates.each do |rate|
        b = rate.blocked?
        fr = SchoolHolidays.france_for(rate.week_start)
        ch = SchoolHolidays.geneva_for(rate.week_start)
        sheet.add_row [
          rate.week_start.cweek, rate.week_start, rate.week_start + NIGHTS_PER_WEEK, self.class.season_for(rate.week_start),
          rate.price_cents / 100.0, (rate.price_cents / 100.0 / NIGHTS_PER_WEEK).round(2),
          fr ? "#{fr[:label]} (#{fr[:zones].join('·')})" : nil, ch ? ch[:label] : nil,
          b ? "Réservée famille" : nil, rate.note
        ],
        types: [ :integer, :date, :date, :string, :float, :float, :string, :string, :string, :string ],
        style: [ b ? @st[:blocked_int] : @st[:int], b ? @st[:blocked_date] : @st[:date], b ? @st[:blocked_date] : @st[:date],
                 b ? @st[:blocked] : @st[:text], b ? @st[:blocked_euro] : @st[:euro], b ? @st[:blocked_euro_dec] : @st[:euro_dec],
                 b ? @st[:blocked] : @st[:text], b ? @st[:blocked] : @st[:text], b ? @st[:blocked] : @st[:text], b ? @st[:blocked] : @st[:wrap] ]
      end

      sheet.column_widths 8, 16, 16, 18, 14, 12, 22, 16, 16, 40
      sheet.auto_filter = "A1:J#{@rates.size + 1}"
      freeze_header(sheet)
    end
  end

  def add_seasons_sheet(workbook)
    periods = self.periods
    workbook.add_worksheet(name: "Saisons") do |sheet|
      sheet.add_row [ "Périodes tarifaires" ], style: @st[:title]
      sheet.add_row [ "Semaines consécutives au même prix, du samedi d'arrivée au samedi de départ." ]
      sheet.add_row []
      sheet.add_row [ "Saison", "Du (samedi)", "Au (samedi)", "Semaines", "Prix / semaine", "Prix / nuit",
                      "Vacances scolaires", "Semaines famille", "Notes" ], style: @st[:header], height: 30
      periods.each do |p|
        sheet.add_row [
          p.season, p.from, p.to, p.weeks, p.price_cents / 100.0, (p.price_cents / 100.0 / NIGHTS_PER_WEEK).round(2),
          self.class.holiday_text(p.holidays), p.blocked.zero? ? nil : p.blocked, p.notes.uniq.join(" ; ").presence
        ],
        types: [ :string, :date, :date, :integer, :float, :float, :string, :integer, :string ],
        style: [ @st[:text], @st[:date], @st[:date], @st[:int], @st[:euro], @st[:euro_dec], @st[:wrap], @st[:int], @st[:wrap] ]
      end

      sheet.add_row []
      sheet.add_row [ "Synthèse par saison" ], style: @st[:title]
      sheet.add_row [ "Saison", "Semaines", "Prix mini / semaine", "Prix maxi / semaine", "Prix moyen / semaine", "Prix moyen / nuit" ],
                    style: @st[:header], height: 30
      summary_rows.each do |row|
        sheet.add_row row, types: [ :string, :integer, :float, :float, :float, :float ],
                           style: [ @st[:text], @st[:int], @st[:euro], @st[:euro], @st[:euro], @st[:euro_dec] ]
      end

      sheet.column_widths 20, 14, 14, 11, 16, 14, 40, 16, 40
      sheet.sheet_view.pane { |pane| pane.state = :frozen; pane.y_split = 4; pane.top_left_cell = "A5"; pane.active_pane = :bottom_left }
    end
  end

  SEASON_ORDER = [ "Noël et Nouvel An", "Hiver", "Printemps", "Été", "Automne" ].freeze

  def summary_rows
    @rates.group_by { |r| self.class.season_for(r.week_start) }
          .sort_by { |season, _| SEASON_ORDER.index(season) || SEASON_ORDER.size }
          .map do |season, rates|
      prices = rates.map(&:price_cents)
      avg = prices.sum / prices.size.to_f
      [ season, rates.size, prices.min / 100.0, prices.max / 100.0, (avg / 100.0).round(2), (avg / NIGHTS_PER_WEEK / 100.0).round(2) ]
    end
  end

  # [[pays, libellé, zones ou nil], …] pour la semaine.
  def holiday_entries(rate)
    entries = []
    if (fr = SchoolHolidays.france_for(rate.week_start))
      entries << [ "FR", fr[:label], fr[:zones] ]
    end
    if (ch = SchoolHolidays.geneva_for(rate.week_start))
      entries << [ "CH", ch[:label], nil ]
    end
    entries
  end

  def freeze_header(sheet)
    sheet.sheet_view.pane { |pane| pane.state = :frozen; pane.y_split = 1; pane.top_left_cell = "A2"; pane.active_pane = :bottom_left }
  end
end
