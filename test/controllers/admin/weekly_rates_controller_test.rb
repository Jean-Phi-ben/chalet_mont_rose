require "test_helper"

class Admin::WeeklyRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email_address: "admin@example.com", password: "motdepasse")
    sign_in_as(@admin)
    @rate = WeeklyRate.create!(week_start: Date.new(2026, 1, 3), price_cents: 100_000)
  end

  test "index flags the current week as the scroll anchor and upcoming weeks as fallback" do
    current = Date.current.beginning_of_week(:saturday)
    WeeklyRate.where(week_start: [ current - 7, current, current + 7 ]).delete_all
    past     = WeeklyRate.create!(week_start: current - 7, price_cents: 100_000)
    today    = WeeklyRate.create!(week_start: current,     price_cents: 100_000)
    upcoming = WeeklyRate.create!(week_start: current + 7, price_cents: 100_000)

    get admin_weekly_rates_url
    assert_response :success
    assert_select "[data-controller~=scroll-to] [data-scroll-to-target=scroller] table thead.sticky"
    assert_select "[data-controller~=scroll-to] button[data-action='scroll-to#jump']", text: /Aujourd'hui/
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(today)}[data-week-period=current][data-scroll-to-target=anchor].cal-today", text: /En cours/
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(upcoming)}[data-week-period=upcoming][data-scroll-to-target=fallback]"
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(past)}[data-week-period=past]:not([data-scroll-to-target])"
    assert_select "tr[data-scroll-to-target=anchor]", 1
  end

  test "index exports the rates grid to Excel with a Grille and a Saisons sheet" do
    xmas = Date.new(2026, 12, 19)
    WeeklyRate.create!(week_start: xmas, price_cents: 920_000, note: "Noël")
    WeeklyRate.create!(week_start: xmas + 7, price_cents: 920_000, blocked: true)

    get admin_weekly_rates_url(format: :xlsx)
    assert_response :success
    assert_equal Mime[:xlsx].to_s, response.media_type
    assert_match(/attachment; filename="tarifs-chalet-mont-rose-\d{4}-\d{2}-\d{2}\.xlsx"/, response.headers["Content-Disposition"])

    Zip::File.open_buffer(response.body) do |zip|
      workbook = zip.read("xl/workbook.xml").force_encoding(Encoding::UTF_8)
      assert_match 'name="Grille"', workbook
      assert_match 'name="Saisons"', workbook
      strings = zip.read("xl/sharedStrings.xml").force_encoding(Encoding::UTF_8)
      assert_match "Réservée famille", strings
      assert_match "Noël et Nouvel An", strings
      assert_match "Synthèse par saison", strings
    end

    # Le bouton d'export est en tête de page.
    get admin_weekly_rates_url
    assert_select "a[href=?]", admin_weekly_rates_path(format: :xlsx), text: /Export Excel/
  end

  test "export groups consecutive same-priced weeks of a season into one period" do
    WeeklyRate.delete_all
    sat = Date.new(2027, 7, 3)
    3.times { |i| WeeklyRate.create!(week_start: sat + 7 * i, price_cents: 500_000) }
    WeeklyRate.create!(week_start: sat + 21, price_cents: 540_000, blocked: true)

    periods = WeeklyRatesExport.new(WeeklyRate.ordered).periods
    assert_equal 2, periods.size
    assert_equal [ "Été", sat, sat + 21, 3, 500_000, 0 ], periods.first.to_h.values_at(:season, :from, :to, :weeks, :price_cents, :blocked)
    assert_equal [ sat + 21, sat + 28, 1, 540_000, 1 ], periods.last.to_h.values_at(:from, :to, :weeks, :price_cents, :blocked)
    assert_equal "FR Été (A·B·C) ; CH Été", WeeklyRatesExport.holiday_text(periods.first.holidays)
  end

  test "holiday_text merges the French zones of a same label" do
    entries = [ [ "FR", "Hiver", %w[C] ], [ "FR", "Hiver", %w[A C] ], [ "CH", "Février", nil ], [ "FR", "Hiver", %w[B] ] ]
    assert_equal "FR Hiver (A·B·C) ; CH Février", WeeklyRatesExport.holiday_text(entries)
    assert_nil WeeklyRatesExport.holiday_text([])
  end

  test "index shows the week number column and inline price field" do
    get admin_weekly_rates_url
    assert_response :success
    assert_select "th", text: "Sem. n°"
    assert_select "td", text: @rate.week_start.cweek.to_s
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@rate)} input[name=?]", "weekly_rate[price_euros]"
  end

  test "inline price update responds with a turbo_stream replacing the row" do
    patch admin_weekly_rate_url(@rate),
          params: { weekly_rate: { price_euros: 1500 } },
          as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match ActionView::RecordIdentifier.dom_id(@rate), response.body
    assert_equal 150_000, @rate.reload.price_cents
  end

  test "ticking Famille blocks the week via turbo_stream and shows it as reserved" do
    rate = WeeklyRate.ordered.first
    patch admin_weekly_rate_url(rate), params: { weekly_rate: { blocked: "1" } }, as: :turbo_stream
    assert_response :success
    assert rate.reload.blocked?
    assert_match "Réservée famille", response.body
    assert_select "tr[data-blocked-week]"
  end

  test "a browser form submission (Turbo Accept header) gets a turbo_stream, not a redirect" do
    rate = WeeklyRate.ordered.first
    patch admin_weekly_rate_url(rate), params: { weekly_rate: { blocked: "1" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "note update via turbo_stream persists the note" do
    patch admin_weekly_rate_url(@rate),
          params: { weekly_rate: { note: "Vacances de février" } },
          as: :turbo_stream

    assert_response :success
    assert_equal "Vacances de février", @rate.reload.note
  end
end
