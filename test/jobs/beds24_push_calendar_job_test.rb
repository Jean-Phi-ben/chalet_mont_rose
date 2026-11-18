require "test_helper"

class Beds24PushCalendarJobTest < ActiveJob::TestCase
  setup do
    Rails.cache.clear
    WeeklyRate.delete_all
    @sat = Date.current.next_occurring(:saturday) + 7
  end

  def with_beds24_env(token: "refresh", room: "42")
    previous = ENV.slice("BEDS24_REFRESH_TOKEN", "BEDS24_ROOM_ID", "STAGING")
    ENV["BEDS24_REFRESH_TOKEN"] = token
    ENV["BEDS24_ROOM_ID"] = room
    ENV.delete("STAGING")
    yield
  ensure
    %w[BEDS24_REFRESH_TOKEN BEDS24_ROOM_ID STAGING].each { |k| previous.key?(k) ? ENV[k] = previous[k] : ENV.delete(k) }
  end

  test "nothing is scheduled while Beds24 is not configured" do
    with_beds24_env(token: nil, room: nil) do
      assert_no_enqueued_jobs { WeeklyRate.create!(week_start: @sat, price_cents: 100_000) }
    end
  end

  test "saving a rate schedules one debounced push, not one per rate" do
    with_beds24_env do
      assert_enqueued_jobs 1, only: Beds24::PushCalendarJob do
        3.times { |i| WeeklyRate.create!(week_start: @sat + 7 * i, price_cents: 100_000) }
      end
    end
  end

  test "confirming or cancelling a booking schedules a push, a pending request does not" do
    with_beds24_env do
      booking = nil
      assert_no_enqueued_jobs(only: Beds24::PushCalendarJob) do
        booking = Booking.create!(check_in: @sat, check_out: @sat + 7, guests_count: 2, first_name: "A", last_name: "B",
                                  email: "a@b.fr", total_price_cents: 100_000, deposit_cents: 30_000)
      end
      assert_enqueued_jobs(1, only: Beds24::PushCalendarJob) { booking.update!(status: :confirmed) }
      Rails.cache.clear # fin de la fenêtre anti-rafale
      assert_enqueued_jobs(1, only: Beds24::PushCalendarJob) { booking.update!(status: :cancelled) }
    end
  end

  test "the job sends the planned calendar to the configured room" do
    with_beds24_env do
      WeeklyRate.create!(week_start: @sat, price_cents: 220_000)
      sent = nil
      fake = Object.new
      fake.define_singleton_method(:write_calendar) { |room_id:, entries:| sent = [ room_id, entries ]; entries.size }
      Beds24::Client.stub_new(fake) { Beds24::PushCalendarJob.perform_now }

      assert_equal 42, sent.first
      assert_equal 2, sent.last.size
      assert_equal({ from: @sat.iso8601, to: @sat.iso8601, price1: 315, price2: 417, minStay: 7, maxStay: 21, numAvail: 1, override: "none" },
                   sent.last.first)
    end
  end
end

# Remplace Beds24::Client.new le temps d'un bloc (Minitest 6 n'embarque plus minitest/mock).
class Beds24::Client
  def self.stub_new(instance)
    singleton_class.alias_method(:original_new, :new)
    define_singleton_method(:new) { |*| instance }
    yield
  ensure
    singleton_class.alias_method(:new, :original_new)
    singleton_class.remove_method(:original_new)
  end
end
