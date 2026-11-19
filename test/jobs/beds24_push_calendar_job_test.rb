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

  def new_booking(status: :pending)
    Booking.create!(check_in: @sat, check_out: @sat + 7, guests_count: 2, first_name: "A", last_name: "B",
                    email: "a@b.fr", total_price_cents: 100_000, deposit_cents: 30_000, status: status)
  end

  test "nothing is scheduled while Beds24 is not configured" do
    with_beds24_env(token: nil, room: nil) do
      assert_no_enqueued_jobs do
        WeeklyRate.create!(week_start: @sat + 7, price_cents: 100_000, blocked: true)
        new_booking(status: :confirmed)
      end
    end
  end

  test "saving rates schedules one debounced calendar push, not one per rate" do
    with_beds24_env do
      assert_enqueued_jobs 1, only: Beds24::PushCalendarJob do
        3.times { |i| WeeklyRate.create!(week_start: @sat + 7 * i, price_cents: 100_000) }
      end
    end
  end

  test "changing the weekly cleaning fee schedules a calendar push, the tourist tax does not" do
    with_beds24_env do
      setting = BookingSetting.current
      assert_no_enqueued_jobs(only: Beds24::PushCalendarJob) { setting.update!(tourist_tax_per_person_per_night_cents: 300) }
      assert_enqueued_jobs(1, only: Beds24::PushCalendarJob) { setting.update!(cleaning_fee_cents: 45_000) }
    end
  end

  test "ticking or unticking Famille schedules a mirror booking push" do
    with_beds24_env do
      rate = nil
      assert_enqueued_with(job: Beds24::PushBookingJob) { rate = WeeklyRate.create!(week_start: @sat, price_cents: 100_000, blocked: true) }
      assert_no_enqueued_jobs(only: Beds24::PushBookingJob) { rate.update!(price_cents: 120_000) }
      assert_enqueued_with(job: Beds24::PushBookingJob, args: [ rate ]) { rate.update!(blocked: false) }
    end
  end

  test "confirming or cancelling a booking schedules a mirror push, a pending request does not" do
    with_beds24_env do
      booking = nil
      assert_no_enqueued_jobs(only: Beds24::PushBookingJob) { booking = new_booking }
      assert_enqueued_with(job: Beds24::PushBookingJob, args: [ booking ]) { booking.update!(status: :confirmed) }
      assert_enqueued_with(job: Beds24::PushBookingJob, args: [ booking ]) { booking.update!(status: :cancelled) }
      assert_no_enqueued_jobs(only: Beds24::PushCalendarJob) { booking.update!(status: :confirmed) }
    end
  end

  test "changing the amount, guests or contact of a confirmed booking updates its mirror" do
    with_beds24_env do
      booking = new_booking(status: :confirmed)
      assert_enqueued_with(job: Beds24::PushBookingJob, args: [ booking ]) { booking.update!(total_price_cents: 1_234_500) }
      assert_enqueued_with(job: Beds24::PushBookingJob, args: [ booking ]) { booking.update!(guests_count: 8) }
      assert_enqueued_with(job: Beds24::PushBookingJob, args: [ booking ]) { booking.update!(phone: "+33600000000") }
      assert_no_enqueued_jobs(only: Beds24::PushBookingJob) { booking.update!(message: "Arrivée tardive") }

      pending = new_booking
      assert_no_enqueued_jobs(only: Beds24::PushBookingJob) { pending.update!(total_price_cents: 1_234_500) }
    end
  end

  test "deleting a mirrored booking schedules its cancellation in Beds24" do
    with_beds24_env do
      booking = new_booking(status: :cancelled)
      booking.update_column(:beds24_booking_id, 777)
      assert_enqueued_with(job: Beds24::CancelBookingJob, args: [ 777 ]) { booking.destroy! }
    end
  end

  test "the calendar job sends the planned calendar to the configured room" do
    with_beds24_env do
      WeeklyRate.create!(week_start: @sat, price_cents: 220_000)
      sent = nil
      fake = Object.new
      fake.define_singleton_method(:write_calendar) { |room_id:, entries:| sent = [ room_id, entries ]; entries.size }
      Beds24::Client.stub_new(fake) { Beds24::PushCalendarJob.perform_now }

      assert_equal 42, sent.first
      assert_equal 2, sent.last.size
      assert_equal({ from: @sat.iso8601, to: @sat.iso8601, price1: 315, price2: 448, minStay: 7, maxStay: 21, numAvail: 1, override: "none" },
                   sent.last.first)
    end
  end

  test "the booking job pushes the record through BookingSync" do
    with_beds24_env do
      booking = new_booking(status: :confirmed)
      fake = Object.new
      fake.define_singleton_method(:post_bookings) { |b| b.map { { "success" => true, "new" => { "id" => 4242 } } } }
      Beds24::Client.stub_new(fake) { Beds24::PushBookingJob.perform_now(booking) }
      assert_equal 4242, booking.reload.beds24_booking_id
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
