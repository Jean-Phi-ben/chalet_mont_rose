require "test_helper"

class ClientTest < ActiveSupport::TestCase
  def booking_attrs(overrides = {})
    {
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "jean@example.com",
      guests_count: 4, phone: "0600000001"
    }.merge(overrides)
  end

  test "a booking save creates a client and links it" do
    assert_difference "Client.count", 1 do
      Booking.create!(booking_attrs.merge(address: "1 rue des Alpes, 75016 Paris"))
    end
    client = Client.find_by(email: "jean@example.com")
    assert client
    assert_equal "Jean",   client.first_name
    assert_equal "Dupont", client.last_name
    assert_equal "0600000001", client.phone
    assert_equal "1 rue des Alpes, 75016 Paris", client.address
    assert_equal client, Booking.last.client
  end

  test "the same email reuses the existing client and updates its address" do
    Booking.create!(booking_attrs)
    assert_no_difference "Client.count" do
      Booking.create!(booking_attrs.merge(
        check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
        address: "2 avenue Mont-Blanc, 74000 Annecy"
      ))
    end
    client = Client.find_by(email: "jean@example.com")
    assert_equal "2 avenue Mont-Blanc, 74000 Annecy", client.address
    assert_equal 2, client.bookings.count
  end

  test "email is normalized to lowercase" do
    Booking.create!(booking_attrs(email: "Jean.Dupont@Example.COM"))
    assert Client.find_by(email: "jean.dupont@example.com")
  end
end
