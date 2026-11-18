require "test_helper"

class Beds24::BookingSyncTest < ActiveSupport::TestCase
  # Faux client : mémorise les corps envoyés et répond comme Beds24.
  class FakeClient
    attr_reader :posted

    def initialize(next_id: 901)
      @posted = []
      @next_id = next_id
    end

    def post_bookings(bookings)
      @posted << bookings
      bookings.map do |b|
        if b[:id]
          { "success" => true, "modified" => { "id" => b[:id] } }
        else
          { "success" => true, "new" => { "id" => (@next_id += 1) } }
        end
      end
    end
  end

  setup do
    WeeklyRate.delete_all
    @sat = Date.current.next_occurring(:saturday) + 7
    @client = FakeClient.new
    @sync = Beds24::BookingSync.new(client: @client, room_id: 42)
    @booking = Booking.create!(check_in: @sat, check_out: @sat + 7, guests_count: 4, first_name: "Nina", last_name: "Test",
                               email: "nina@example.com", phone: "06 12 34 56 78", total_price_cents: 242_000, deposit_cents: 72_600,
                               status: :confirmed)
  end

  test "a confirmed booking is created in Beds24 and its id stored, then modified by id" do
    assert_equal 902, @sync.push(@booking)
    assert_equal 902, @booking.reload.beds24_booking_id

    sent = @client.posted.first.first
    assert_equal [ 42, "confirmed", @sat.iso8601, (@sat + 7).iso8601, 4, "Nina", "Test", 2420.0, "cmr-booking-#{@booking.id}", false ],
                 sent.values_at(:roomId, :status, :arrival, :departure, :numAdult, :firstName, :lastName, :price, :apiReference, :allowWebhooks)
    assert_equal "Site chaletmontrose.fr", sent[:referer]
    assert_nil sent[:id]

    @booking.update!(guests_count: 6)
    @sync.push(@booking)
    assert_equal 902, @client.posted.last.first[:id]
    assert_equal 6, @client.posted.last.first[:numAdult]
  end

  test "a cancelled booking with a mirror is cancelled in Beds24; without a mirror nothing is sent" do
    @booking.update_column(:beds24_booking_id, 555)
    @booking.update!(status: :cancelled)
    assert_equal 555, @sync.push(@booking)
    assert_equal({ status: "cancelled", allowWebhooks: false, id: 555 }, @client.posted.last.first)

    never_synced = Booking.create!(check_in: @sat + 14, check_out: @sat + 21, guests_count: 2, first_name: "A", last_name: "B",
                                   email: "a@b.fr", total_price_cents: 100_000, deposit_cents: 30_000)
    assert_nil @sync.push(never_synced)
    assert_equal 1, @client.posted.size
  end

  test "a family week becomes a black booking, unticking it cancels the mirror" do
    rate = WeeklyRate.create!(week_start: @sat + 14, price_cents: 300_000, blocked: true)
    assert_equal 902, @sync.push(rate)
    sent = @client.posted.first.first
    assert_equal [ "black", (@sat + 14).iso8601, (@sat + 21).iso8601, "Famille", "cmr-family-#{(@sat + 14).iso8601}" ],
                 sent.values_at(:status, :arrival, :departure, :firstName, :apiReference)
    assert_equal 902, rate.reload.beds24_booking_id

    rate.update!(blocked: false)
    @sync.push(rate)
    assert_equal({ status: "cancelled", allowWebhooks: false, id: 902 }, @client.posted.last.first)
  end

  test "a refusal from Beds24 raises a client error" do
    refusing = Object.new
    refusing.define_singleton_method(:post_bookings) { |_| [ { "success" => false, "errors" => { "arrival" => "in the past" } } ] }
    error = assert_raises(Beds24::Client::Error) { Beds24::BookingSync.new(client: refusing, room_id: 42).push(@booking) }
    assert_match "arrival", error.message
    assert_nil @booking.reload.beds24_booking_id
  end
end
