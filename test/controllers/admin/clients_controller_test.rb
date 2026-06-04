require "test_helper"

class Admin::ClientsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Date.new(2025, 12, 1)
    @admin = User.create!(email_address: "admin@example.com", password: "password", admin: true)
    sign_in_as(@admin)
    Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "jean@example.com",
      guests_count: 4, total_price_cents: 220_000, deposit_cents: 66_000,
      address: "1 rue des Alpes"
    )
    @client = Client.find_by(email: "jean@example.com")
  end

  teardown { travel_back }

  test "show displays the client details and bookings" do
    get admin_client_url(@client)
    assert_response :success
    assert_select "h1", text: /Jean Dupont/
    assert_match "1 rue des Alpes", response.body
    # Au moins une réservation liée dans le tableau.
    assert_select "a", text: "Voir", minimum: 1
  end

  test "admin bookings index links the client name to the profile" do
    get admin_bookings_url
    assert_response :success
    assert_select "a[href=?]", admin_client_path(@client), text: /Jean Dupont/
  end

  test "edit renders the form with email locked" do
    get edit_admin_client_url(@client)
    assert_response :success
    assert_select "input[name='client[first_name]']"
    assert_select "input[name='client[email]']", count: 0
    assert_select "input[type=email][disabled]"
  end

  test "update modifies allowed fields but ignores email" do
    patch admin_client_url(@client), params: {
      client: { first_name: "Jeanne", last_name: "Durand", phone: "0612345678",
                address: "12 rue Alpine", email: "hacker@example.com" }
    }
    assert_redirected_to admin_client_path(@client)
    @client.reload
    assert_equal "Jeanne",         @client.first_name
    assert_equal "Durand",         @client.last_name
    assert_equal "0612345678",     @client.phone
    assert_equal "12 rue Alpine",  @client.address
    assert_equal "jean@example.com", @client.email   # email ignoré
  end

  test "update propagates name and phone to existing bookings" do
    booking = @client.bookings.first
    patch admin_client_url(@client), params: {
      client: { first_name: "Jeanne", last_name: "Durand", phone: "0612345678", address: "x" }
    }
    booking.reload
    assert_equal "Jeanne",     booking.first_name
    assert_equal "Durand",     booking.last_name
    assert_equal "0612345678", booking.phone
  end
end
