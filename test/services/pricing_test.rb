require "test_helper"

class PricingTest < ActiveSupport::TestCase
  setup do
    @check_in  = Date.new(2026, 1, 3)
    @check_out = Date.new(2026, 1, 17)
    WeeklyRate.create!(week_start: Date.new(2026, 1, 3),  price_cents: 100_000)
    WeeklyRate.create!(week_start: Date.new(2026, 1, 10), price_cents: 120_000)
  end

  test "returns a bookable quote with the full breakdown" do
    q = Pricing.quote(@check_in, @check_out, guests_count: 4)
    assert q[:bookable]
    assert_equal 220_000, q[:accommodation_cents]
    # Ménage : 40 000 ct/sem × 2 semaines.
    assert_equal 80_000, q[:cleaning_cents]
    # Taxe : 260 ct × 4 voyageurs × 14 nuits.
    assert_equal 14_560, q[:tax_cents]
    assert_equal 314_560, q[:total_cents]
    # Arrhes : 30 % de l'hébergement seulement.
    assert_equal 66_000, q[:deposit_cents]
  end

  test "returns semaine_indisponible when overlapping a confirmed booking" do
    Booking.create!(
      check_in: @check_in, check_out: @check_out,
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      total_price_cents: 220_000, deposit_cents: 66_000, status: :confirmed
    )
    q = Pricing.quote(@check_in, @check_out)
    refute q[:bookable]
    assert_equal "semaine_indisponible", q[:reason]
  end

  test "except_id ignores the target booking when checking overlap" do
    existing = Booking.create!(
      check_in: @check_in, check_out: @check_out,
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      total_price_cents: 220_000, deposit_cents: 66_000, status: :confirmed
    )
    q = Pricing.quote(@check_in, @check_out, except_id: existing.id)
    assert q[:bookable]
  end
end
