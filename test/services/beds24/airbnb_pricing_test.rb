require "test_helper"

class Beds24::AirbnbPricingTest < ActiveSupport::TestCase
  test "coefficients for the three markup objectives" do
    assert_in_delta 1.1834, Beds24::AirbnbPricing.coefficient(:payout, host_fee: "0.155"), 0.0001
    assert_in_delta 1.2055, Beds24::AirbnbPricing.coefficient(:net_ht, host_fee: "0.155", vat_on_stay: BigDecimal("0.10")), 0.0001
    assert_in_delta 1.2285, Beds24::AirbnbPricing.coefficient(:no_vat_recovery, host_fee: "0.155"), 0.0001
    assert_raises(ArgumentError) { Beds24::AirbnbPricing.coefficient(:naive) }
  end

  test "net_ht preserves the net revenue excluding VAT after the host fee" do
    week_direct = 220_000 # 2 200 € + 220 € de ménage = 2 420 € payés en direct
    nightly = Beds24::AirbnbPricing.nightly_euros(week_direct, mode: :net_ht, cleaning_rate: "0.10")
    assert_equal 417, nightly
    gross = nightly * 7
    net_ht_airbnb = gross / 1.10 - gross * 0.155
    net_ht_direct = (week_direct / 100.0 * 1.10) / 1.10
    assert_in_delta net_ht_direct, net_ht_airbnb, 5, "écart dû au seul arrondi à l'euro par nuit"
  end

  test "nightly prices are whole euros rounded up" do
    assert_equal 315, Beds24::AirbnbPricing.direct_nightly_euros(220_000) # 2200/7 = 314,29
    assert_equal 1315, Beds24::AirbnbPricing.direct_nightly_euros(920_000)
    assert_equal 1743, Beds24::AirbnbPricing.nightly_euros(920_000, mode: :net_ht, cleaning_rate: "0.10")
  end
end
