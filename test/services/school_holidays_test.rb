require "test_helper"

class SchoolHolidaysTest < ActiveSupport::TestCase
  test "detects a week fully inside a french holiday period" do
    holiday = SchoolHolidays.france_for(Date.new(2027, 2, 13)) # vacances d'hiver
    assert holiday
    assert_equal "Hiver", holiday[:label]
  end

  test "reports the french zones on holiday that week" do
    # Semaine du 7 fév. 2026 : seule la zone A couvre tout le séjour (A: 7-23 fév.).
    assert_equal %w[A], SchoolHolidays.france_for(Date.new(2026, 2, 7))[:zones]
    # Semaine du 20 fév. 2027 : A et B couvrent le séjour ; C reprend le lundi 22.
    assert_equal %w[A B], SchoolHolidays.france_for(Date.new(2027, 2, 20))[:zones]
    # Toussaint : commun aux trois zones.
    assert_equal %w[A B C], SchoolHolidays.france_for(Date.new(2026, 10, 17))[:zones]
  end

  test "only flags weeks fully inside the holiday (saturday to saturday)" do
    # Toussaint 2026 : 17 oct. → reprise lundi 2 nov.
    assert SchoolHolidays.france_for(Date.new(2026, 10, 17)) # 17→24 : compris
    assert SchoolHolidays.france_for(Date.new(2026, 10, 24)) # 24→31 : compris
    assert_nil SchoolHolidays.france_for(Date.new(2026, 10, 31)) # 31→7 nov : école dès le 2 nov.
    assert_nil SchoolHolidays.france_for(Date.new(2026, 10, 10)) # 10→17 : avant le début
  end

  test "treats the reprise (monday) date as an exclusive bound" do
    # Genève — février 2027 : 15 au 19 (reprise lundi 22). La semaine du 20 ne chevauche plus.
    assert SchoolHolidays.geneva_for(Date.new(2027, 2, 13)) # 13→20 chevauche le 15-19
    assert_nil SchoolHolidays.geneva_for(Date.new(2027, 2, 20)) # 20→27 ne chevauche plus
  end

  test "returns nil outside any holiday period" do
    assert_nil SchoolHolidays.france_for(Date.new(2027, 5, 8))
    assert_nil SchoolHolidays.geneva_for(Date.new(2027, 5, 8))
  end

  test "noel week overlaps both countries" do
    sat = Date.new(2026, 12, 26)
    assert SchoolHolidays.france_for(sat)
    assert SchoolHolidays.geneva_for(sat)
  end

  test "handles nil week start" do
    assert_nil SchoolHolidays.france_for(nil)
  end
end
