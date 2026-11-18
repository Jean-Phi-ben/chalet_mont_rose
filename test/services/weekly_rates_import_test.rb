require "test_helper"

class WeeklyRatesImportTest < ActiveSupport::TestCase
  setup do
    WeeklyRate.delete_all
    @sat = Date.new(2027, 1, 9)
    @existing = WeeklyRate.create!(week_start: @sat, price_cents: 520_000, note: "à garder", blocked: true)
  end

  test "dry run reports creations and changes without writing" do
    changes = WeeklyRatesImport.new([ [ @sat, 5270 ], [ @sat + 7, 5270 ] ]).call(dry_run: true)
    assert_equal [ 520_000, 527_000 ], [ changes[0].before_cents, changes[0].after_cents ]
    assert changes[1].created?
    assert_equal 520_000, @existing.reload.price_cents
    assert_equal 1, WeeklyRate.count
  end

  test "import updates prices, creates missing weeks and keeps notes and family flags" do
    WeeklyRatesImport.new([ [ @sat, 5270 ], [ @sat + 7, 8075 ] ]).call
    @existing.reload
    assert_equal 527_000, @existing.price_cents
    assert_equal "à garder", @existing.note
    assert @existing.blocked?
    assert_equal 807_500, WeeklyRate.find_by!(week_start: @sat + 7).price_cents
  end

  test "rejects non-Saturday dates, duplicates and bad prices" do
    assert_raises(WeeklyRatesImport::InvalidRow) { WeeklyRatesImport.new([ [ @sat + 1, 100 ] ]) }
    assert_raises(WeeklyRatesImport::InvalidRow) { WeeklyRatesImport.new([ [ @sat, 100 ], [ @sat, 200 ] ]) }
    assert_raises(WeeklyRatesImport::InvalidRow) { WeeklyRatesImport.new([ [ @sat, 0 ] ]) }
  end

  test "the versioned 2026-11-18 grid parses: 58 Saturdays from 21/11/2026 to 25/12/2027" do
    import = WeeklyRatesImport.from_csv(Rails.root.join("db/data/weekly_rates_2026-11-18.csv"))
    rows = import.instance_variable_get(:@rows)
    assert_equal 58, rows.size
    assert_equal [ Date.new(2026, 11, 21), 3825 ], rows.first
    assert_equal [ Date.new(2027, 12, 25), 9350 ], rows.last
    assert_equal rows.map(&:first), (0...58).map { |i| Date.new(2026, 11, 21) + 7 * i }, "semaines consécutives sans trou"
  end
end
