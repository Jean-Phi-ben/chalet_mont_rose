require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Date.new(2026, 5, 30) }
  teardown { travel_back }

  # Le calendrier est une section de la page d'accueil (#disponibilites).

  test "old /calendrier URL redirects to the home availability section" do
    get calendar_url
    assert_redirected_to "/#disponibilites"
  end

  test "calendar renders multiple months stacked (no month-by-month navigation)" do
    WeeklyRate.create!(week_start: Date.new(2026, 7, 4), price_cents: 100_000)
    get root_url
    assert_response :success
    # mois courant + plusieurs suivants empilés.
    assert_select "#disponibilites p", text: /mai 2026/i, minimum: 1
    assert_select "#disponibilites p", text: /juin 2026/i, minimum: 1
    assert_select "#disponibilites p", text: /juillet 2026/i, minimum: 1
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

    get root_url
    assert_response :success
    # 7 jours du séjour confirmé barrés + jours passés (depuis le 1er mai jusqu'au 29).
    assert_select "#disponibilites .line-through", minimum: 7
  end

  test "every non-past, non-blocked day in the visible month is clickable" do
    get root_url
    assert_response :success
    # 30 mai 2026 (jour courant) cliquable, et n'importe quel jour futur du mois courant.
    assert_select "#disponibilites [data-date='2026-05-30'][data-action='click->calendar#pick']", 1
    # Un mercredi (1er juillet 2026) doit aussi être cliquable, pas juste les samedis.
    assert_select "#disponibilites [data-date='2026-07-01'][data-action='click->calendar#pick']", 1
  end

  test "quote refuses the current week once it has started" do
    # 30 mai 2026 = samedi ; on se place au mardi 2 juin, semaine du 30 mai entamée.
    travel_to Date.new(2026, 6, 2)
    WeeklyRate.create!(week_start: Date.new(2026, 5, 30), price_cents: 100_000)
    WeeklyRate.create!(week_start: Date.new(2026, 6, 6), price_cents: 100_000)

    get calendar_quote_url, params: { check_in: "2026-05-30", check_out: "2026-06-06" }
    assert_equal "semaine_commencee", response.parsed_body["reason"]

    get calendar_quote_url, params: { check_in: "2026-06-06", check_out: "2026-06-13" }
    assert response.parsed_body["bookable"]
  end

  test "current-week days explain that arrival moves to next Saturday" do
    travel_to Date.new(2026, 6, 2) # mardi
    get root_url
    assert_select "#disponibilites [data-date='2026-06-04'][title*='samedi suivant']", 1
  end

  test "home page calendar and date picker share one calendar controller" do
    get root_url
    assert_response :success
    assert_select "[data-controller='calendar']", 1
    assert_select "[data-controller='calendar'] #disponibilites", 1
    assert_select "[data-controller='calendar'] #reservation-modal", 1
  end
end
