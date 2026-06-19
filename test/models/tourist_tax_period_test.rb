require "test_helper"

class TouristTaxPeriodTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Date.new(2026, 5, 30) }
  teardown { travel_back }

  test "summer range covers May 1 to September 30" do
    p = TouristTaxPeriod.new(season: "summer", year: 2025)
    assert_equal Date.new(2025, 5, 1),  p.range.begin
    assert_equal Date.new(2025, 9, 30), p.range.end
    assert_match "mai", p.label
    assert p.completed?
  end

  test "winter range straddles two calendar years" do
    p = TouristTaxPeriod.new(season: "winter", year: 2024)
    assert_equal Date.new(2024, 10, 1), p.range.begin
    assert_equal Date.new(2025, 4, 30), p.range.end
    assert_match "octobre", p.label
    assert p.completed?
  end

  test "tax_total_cents sums only fully paid bookings within the period" do
    # Réservation été 2025 totalement payée → comptée.
    paid = Booking.create!(
      check_in: Date.new(2025, 6, 7), check_out: Date.new(2025, 6, 14),
      first_name: "Anne", last_name: "Payée", email: "anne@example.com",
      guests_count: 4,
      accommodation_cents: 100_000, cleaning_fee_cents: 40_000, tourist_tax_cents: 7_280,
      total_price_cents: 147_280, deposit_cents: 30_000, status: :confirmed
    )
    Invoice.from_booking(paid).each do |inv|
      inv.status = :received
      inv.save!
    end

    # Réservation été 2025 dont seules les arrhes sont reçues → exclue.
    half = Booking.create!(
      check_in: Date.new(2025, 7, 5), check_out: Date.new(2025, 7, 12),
      first_name: "Bertrand", last_name: "Partiel", email: "b@example.com",
      guests_count: 2,
      accommodation_cents: 100_000, cleaning_fee_cents: 40_000, tourist_tax_cents: 3_640,
      total_price_cents: 143_640, deposit_cents: 30_000, status: :confirmed
    )
    Invoice.from_booking(half).each(&:save!)
    half.deposit_invoice.mark_received!  # solde reste « awaiting »

    period = TouristTaxPeriod.new(season: "summer", year: 2025)
    assert_equal 7_280, period.tax_total_cents
  end

  test "completed_periods enumerates past summer and winter from the earliest booking" do
    Booking.create!(
      check_in: Date.new(2025, 6, 7), check_out: Date.new(2025, 6, 14),
      first_name: "Anne", last_name: "Payée", email: "anne@example.com",
      accommodation_cents: 100_000, tourist_tax_cents: 7_280,
      total_price_cents: 147_280, deposit_cents: 30_000
    )

    seasons_years = TouristTaxPeriod.completed_periods.map { |p| [ p.season, p.year ] }
    # On part de l'année de la 1re réservation (2025) ⇒ été 2025 (clos 30 sept 2025)
    # et hiver 2025 (clos 30 avr 2026) sont les deux périodes passées attendues.
    assert_equal [ [ "summer", 2025 ], [ "winter", 2025 ] ], seasons_years
    # été 2026 n'est PAS encore clos (on est le 30 mai 2026).
    refute_includes seasons_years, [ "summer", 2026 ]
  end
end
