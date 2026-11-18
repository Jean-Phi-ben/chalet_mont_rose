require "test_helper"

class Beds24::CalendarPlannerTest < ActiveSupport::TestCase
  setup do
    WeeklyRate.delete_all
    Booking.delete_all
    @sat = Date.current.next_occurring(:saturday) + 7
  end

  test "a free week becomes two entries: Saturday open, Sunday→Friday closed to arrival" do
    WeeklyRate.create!(week_start: @sat, price_cents: 220_000)
    entries = Beds24::CalendarPlanner.new.entries

    assert_equal 2, entries.size
    saturday, rest = entries
    assert_equal [ @sat, @sat, 315, 1, "none", 7, 21 ], saturday.to_h.values_at(:from, :to, :price1, :numAvail, :override, :minStay, :maxStay)
    assert_equal [ @sat + 1, @sat + 6, 1, "noCheckIn" ], rest.to_h.values_at(:from, :to, :numAvail, :override)
    assert_equal saturday.price2, rest.price2
    assert_operator saturday.price2, :>, saturday.price1
  end

  test "family weeks and confirmed bookings are pushed as blackout nights with no availability" do
    WeeklyRate.create!(week_start: @sat, price_cents: 220_000, blocked: true)
    WeeklyRate.create!(week_start: @sat + 7, price_cents: 220_000)
    WeeklyRate.create!(week_start: @sat + 14, price_cents: 300_000)
    Booking.create!(check_in: @sat + 7, check_out: @sat + 14, guests_count: 2, first_name: "A", last_name: "B",
                    email: "a@b.fr", total_price_cents: 220_000, deposit_cents: 66_000, status: :confirmed)

    entries = Beds24::CalendarPlanner.new.entries
    # Famille + réservation = 14 nuits consécutives identiques (même prix) → une seule plage.
    blackout = entries.first
    assert_equal [ @sat, @sat + 13, 0, "blackout" ], blackout.to_h.values_at(:from, :to, :numAvail, :override)
    assert_equal [ @sat + 14, @sat + 14, "none" ], entries[1].to_h.values_at(:from, :to, :override)
    assert_equal [ @sat + 15, @sat + 20, "noCheckIn" ], entries[2].to_h.values_at(:from, :to, :override)
    assert_equal 3, entries.size
  end

  test "past weeks are ignored and payload uses ISO dates" do
    WeeklyRate.create!(week_start: @sat - 21, price_cents: 100_000) # semaine passée (avant la semaine courante)
    WeeklyRate.create!(week_start: @sat, price_cents: 100_000)
    planner = Beds24::CalendarPlanner.new
    assert_equal @sat, planner.first_night
    assert_equal @sat + 6, planner.last_night
    assert_equal @sat.iso8601, planner.entries.first.payload[:from]
  end

  test "no rates means no entries" do
    assert_equal [], Beds24::CalendarPlanner.new.entries
  end
end
