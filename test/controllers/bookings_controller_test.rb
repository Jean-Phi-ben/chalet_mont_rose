require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Date.new(2026, 5, 30) }
  teardown { travel_back }

  test "calendar renders multiple months stacked (no month-by-month navigation)" do
    WeeklyRate.create!(week_start: Date.new(2026, 7, 4), price_cents: 100_000)
    get calendar_url
    assert_response :success
    # mois courant + plusieurs suivants empilés.
    assert_select "p", text: /mai 2026/i, minimum: 1
    assert_select "p", text: /juin 2026/i, minimum: 1
    assert_select "p", text: /juillet 2026/i, minimum: 1
    # plus de liens de navigation entre mois.
    assert_select "a[href*='month=']", count: 0
  end

  test "calendar strikes through dates booked by a confirmed booking" do
    WeeklyRate.create!(week_start: Date.new(2026, 6, 6), price_cents: 100_000)
    Booking.create!(
      check_in: Date.new(2026, 6, 6), check_out: Date.new(2026, 6, 13),
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      total_price_cents: 100_000, deposit_cents: 30_000, status: :confirmed
    )

    get calendar_url
    assert_response :success
    # 7 jours du séjour confirmé barrés + jours passés (depuis le 1er mai jusqu'au 29).
    assert_select ".line-through", minimum: 7
  end

  test "every non-past, non-blocked day in the visible month is clickable" do
    get calendar_url
    assert_response :success
    # 30 mai 2026 (jour courant) cliquable, et n'importe quel jour futur du mois courant.
    assert_select "[data-date='2026-05-30'][data-action='click->calendar#pick']", 1
    # Un mercredi (1er juillet 2026) doit aussi être cliquable, pas juste les samedis.
    assert_select "[data-date='2026-07-01'][data-action='click->calendar#pick']", 1
  end
end
