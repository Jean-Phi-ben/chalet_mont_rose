require "test_helper"

class Beds24::AirbnbPricingTest < ActiveSupport::TestCase
  test "coefficients for the three markup objectives" do
    assert_in_delta 1.1834, Beds24::AirbnbPricing.coefficient(:payout, host_fee: "0.155"), 0.0001
    assert_in_delta 1.2055, Beds24::AirbnbPricing.coefficient(:net_ht, host_fee: "0.155", vat_on_stay: BigDecimal("0.10")), 0.0001
    assert_in_delta 1.2285, Beds24::AirbnbPricing.coefficient(:no_vat_recovery, host_fee: "0.155"), 0.0001
    assert_raises(ArgumentError) { Beds24::AirbnbPricing.coefficient(:naive) }
  end

  test "net_ht preserves the net revenue excluding VAT after the host fee, weekly cleaning included" do
    week_direct = 382_900 # 3 829 € + 400 € de ménage = 4 229 € payés en direct
    nightly = Beds24::AirbnbPricing.nightly_euros(week_direct, cleaning_week_cents: 40_000, mode: :net_ht)
    assert_equal 729, nightly # (3829 + 400) × 1,2055 / 7 = 728,3
    gross = nightly * 7
    net_ht_airbnb = gross / 1.10 - gross * 0.155
    net_ht_direct = (week_direct + 40_000) / 100.0 / 1.10
    assert_in_delta net_ht_direct, net_ht_airbnb, 5, "écart dû au seul arrondi à l'euro par nuit"
  end

  test "the weekly cleaning fee is a fixed amount, not a share of the week price" do
    low  = Beds24::AirbnbPricing.nightly_euros(272_300, cleaning_week_cents: 40_000, mode: :net_ht)
    high = Beds24::AirbnbPricing.nightly_euros(935_200, cleaning_week_cents: 40_000, mode: :net_ht)
    assert_equal 538, low   # (2723 + 400) × 1,2055 / 7 = 537,8
    assert_equal 1680, high # (9352 + 400) × 1,2055 / 7 = 1679,4
    assert_equal 469, Beds24::AirbnbPricing.nightly_euros(272_300, cleaning_week_cents: 0, mode: :net_ht) # 2723 × 1,2055 / 7 = 468,9
  end

  test "nightly prices are whole euros rounded up" do
    assert_equal 315, Beds24::AirbnbPricing.direct_nightly_euros(220_000) # 2200/7 = 314,29
    assert_equal 1315, Beds24::AirbnbPricing.direct_nightly_euros(920_000)
  end
end
