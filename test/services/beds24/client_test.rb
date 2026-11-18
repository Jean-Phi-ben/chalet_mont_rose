require "test_helper"

class Beds24::ClientTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @stubs = Faraday::Adapter::Test::Stubs.new
    connection = Faraday.new(url: "https://api.beds24.test/v2/") do |f|
      f.request  :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, @stubs
    end
    @client = Beds24::Client.new(refresh_token: "refresh-xyz", connection: connection)
    @token_calls = 0
    @stubs.get("/v2/authentication/token") do |env|
      @token_calls += 1
      assert_equal "refresh-xyz", env.request_headers["refreshToken"]
      [ 200, { "Content-Type" => "application/json" }, { token: "access-#{@token_calls}", expiresIn: 86_400 }.to_json ]
    end
  end

  test "write_calendar posts the room calendar with the cached access token" do
    posted = nil
    @stubs.post("/v2/inventory/rooms/calendar") do |env|
      assert_equal "access-1", env.request_headers["token"]
      posted = JSON.parse(env.body)
      [ 200, { "Content-Type" => "application/json" }, [ { success: true } ].to_json ]
    end

    entries = [ { from: "2027-01-09", to: "2027-01-09", price1: 753, price2: 999, minStay: 7, maxStay: 21, numAvail: 1, override: "none" } ]
    assert_equal 1, @client.write_calendar(room_id: 42, entries: entries)
    assert_equal 1, @client.write_calendar(room_id: 42, entries: entries)
    assert_equal 1, @token_calls, "le jeton est mis en cache entre deux appels"
    assert_equal [ { "roomId" => 42, "calendar" => [ entries.first.stringify_keys ] } ], posted
  end

  test "a refused write raises with the Beds24 message" do
    @stubs.post("/v2/inventory/rooms/calendar") do
      [ 200, { "Content-Type" => "application/json" }, [ { success: false, errors: { price1: "invalid" } } ].to_json ]
    end
    error = assert_raises(Beds24::Client::Error) { @client.write_calendar(room_id: 42, entries: [ { from: "2027-01-09", to: "2027-01-09" } ]) }
    assert_match "price1", error.message
  end

  test "an expired token is refreshed once and the request replayed" do
    calls = 0
    @stubs.get("/v2/properties") do |env|
      calls += 1
      if env.request_headers["token"] == "access-1"
        [ 401, { "Content-Type" => "application/json" }, { error: "expired" }.to_json ]
      else
        [ 200, { "Content-Type" => "application/json" }, { data: [ { id: 1, name: "Chalet" } ] }.to_json ]
      end
    end
    assert_equal [ { "id" => 1, "name" => "Chalet" } ], @client.properties
    assert_equal 2, calls
    assert_equal 2, @token_calls
  end

  test "a missing refresh token is refused before any call" do
    assert_raises(Beds24::Client::AuthError) { Beds24::Client.new(refresh_token: nil) }
  end
end
