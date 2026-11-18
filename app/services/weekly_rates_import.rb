require "csv"

# Import d'une grille de tarifs hebdomadaires depuis un CSV `week_start,price_euros`
# (une ligne par samedi d'arrivée). Crée les semaines absentes, met à jour le prix des
# semaines existantes, ne touche ni aux notes ni aux semaines « Famille ».
#
#   WeeklyRatesImport.from_csv("db/data/tarifs.csv").call(dry_run: true)
#
# Le résultat liste chaque changement (ancien → nouveau prix) ; en dry run rien n'est écrit.
class WeeklyRatesImport
  Change = Struct.new(:week_start, :before_cents, :after_cents, keyword_init: true) do
    def created? = before_cents.nil?
    def changed? = before_cents != after_cents
  end

  class InvalidRow < StandardError; end

  def self.from_csv(path)
    rows = CSV.read(path, headers: true).map do |row|
      [ Date.iso8601(row.fetch("week_start").to_s.strip), Integer(row.fetch("price_euros").to_s.strip, 10) ]
    rescue ArgumentError, KeyError => e
      raise InvalidRow, "ligne #{row.to_h.inspect} : #{e.message}"
    end
    new(rows)
  end

  # rows : [[Date samedi, prix en euros], …]
  def initialize(rows)
    @rows = rows
    validate!
  end

  def call(dry_run: false)
    changes = @rows.map do |week_start, euros|
      rate = WeeklyRate.find_or_initialize_by(week_start: week_start)
      Change.new(week_start: week_start, before_cents: rate.persisted? ? rate.price_cents : nil, after_cents: euros * 100)
    end
    return changes if dry_run

    WeeklyRate.transaction do
      @rows.each do |week_start, euros|
        rate = WeeklyRate.find_or_initialize_by(week_start: week_start)
        rate.price_cents = euros * 100
        rate.save!
      end
    end
    changes
  end

  private

  def validate!
    raise InvalidRow, "aucune ligne" if @rows.empty?
    @rows.each do |week_start, euros|
      raise InvalidRow, "#{week_start} n'est pas un samedi" unless week_start.saturday?
      raise InvalidRow, "#{week_start} : prix invalide (#{euros})" unless euros.positive?
    end
    dupes = @rows.map(&:first).tally.select { |_, n| n > 1 }.keys
    raise InvalidRow, "semaines en double : #{dupes.join(', ')}" if dupes.any?
  end
end
