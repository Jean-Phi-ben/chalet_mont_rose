require "test_helper"

class Admin::WeeklyRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email_address: "admin@example.com", password: "password", admin: true)
    sign_in_as(@admin)
    @rate = WeeklyRate.create!(week_start: Date.new(2026, 1, 3), price_cents: 100_000)
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

  test "note update via turbo_stream persists the note" do
    patch admin_weekly_rate_url(@rate),
          params: { weekly_rate: { note: "Vacances de février" } },
          as: :turbo_stream

    assert_response :success
    assert_equal "Vacances de février", @rate.reload.note
  end
end
