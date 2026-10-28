require "test_helper"

class I18nConfigTest < ActiveSupport::TestCase
  test "french locale, Paris time zone, French validation messages and date formats" do
    assert_equal :fr, I18n.default_locale
    assert_equal "Europe/Paris", Time.zone.name

    booking = Booking.new
    booking.valid?
    assert_match "Date d'arrivée doit être rempli", booking.errors.full_messages.to_sentence

    assert_equal "9 mai 2026", I18n.l(Date.new(2026, 5, 9), format: :long)
    assert_equal "samedi 9 mai 2026", I18n.l(Date.new(2026, 5, 9), format: :full)
    assert_equal "9 mai 2026 à 14:05", I18n.l(Time.zone.local(2026, 5, 9, 14, 5), format: :long)
  end
end
