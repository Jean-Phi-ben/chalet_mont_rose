require "test_helper"

class Lot7HelpersTest < ActionView::TestCase
  include PricingHelper
  include StatusHelper
  include TypographyHelper
  include MoneyHelper

  NBSP = " "

  test "deposit_rate_label follows Pricing.deposit_rate and survives an empty DEPOSIT_RATE" do
    original = ENV["DEPOSIT_RATE"]
    ENV["DEPOSIT_RATE"] = ""
    assert_equal 0.30, Pricing.deposit_rate
    assert_equal "30 %", deposit_rate_label
    ENV["DEPOSIT_RATE"] = "0.325"
    assert_equal "32,5 %", deposit_rate_label
  ensure
    ENV["DEPOSIT_RATE"] = original
  end

  test "booking_status_badge gives a French label and never raw status" do
    booking = Booking.new(status: :pending)
    html = booking_status_badge(booking)
    assert_match "En attente", html
    assert_no_match(/pending/, html)
    assert_match "En attente de validation", booking_status_badge(booking, long: true)
    assert_equal "Annulée", booking_status_label("cancelled")
  end

  test "caution_status_label is French" do
    assert_equal "Caution non créée", caution_status_label(nil)
    assert_equal "Caution : en attente de dépôt", caution_status_label(Caution.new(status: :pending))
    assert_equal "Caution : déposée", caution_status_label(Caution.new(status: :accepted))
  end

  test "nbsp_punct and fr_plural" do
    assert_equal "Une question#{NBSP}? 30#{NBSP}% · 260#{NBSP}m²", nbsp_punct("Une question ? 30 % · 260 m²")
    assert_equal "1 nuit", fr_plural(1, "nuit")
    assert_equal "2 nuits", fr_plural(2, "nuit")
    assert_equal "3 jeux", fr_plural(3, "jeu", "jeux")
  end

  test "money uses non-breaking spaces between thousands and before the unit" do
    assert_equal "5#{NBSP}800#{NBSP}€", money(580_000)
    assert_equal "1#{NBSP}234,50#{NBSP}€", money(123_450)
    assert_equal "—", money(nil)
  end
end
