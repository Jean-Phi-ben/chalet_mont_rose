require "test_helper"

class BookingTest < ActiveSupport::TestCase
  # Janvier 2026 : le 3 est un samedi (1er = jeudi).
  def valid_attributes(overrides = {})
    {
      check_in: Date.new(2026, 1, 3),
      check_out: Date.new(2026, 1, 17),
      first_name: "Jean",
      last_name: "Dupont",
      email: "jean@example.com",
      guests_count: 4
    }.merge(overrides)
  end

  test "valid with proper attributes" do
    assert Booking.new(valid_attributes).valid?
  end

  test "requires first name, last name and email" do
    booking = Booking.new(valid_attributes(first_name: nil, last_name: nil, email: nil))
    assert booking.invalid?
    assert booking.errors[:first_name].any?
    assert booking.errors[:last_name].any?
    assert booking.errors[:email].any?
  end

  test "rejects a malformed email" do
    booking = Booking.new(valid_attributes(email: "not-an-email"))
    assert booking.invalid?
    assert booking.errors[:email].any?
  end

  test "rejects an email without a top-level domain" do
    booking = Booking.new(valid_attributes(email: "jean@benoist"))
    assert booking.invalid?
    assert booking.errors[:email].any?
  end

  test "check_in must be a saturday" do
    booking = Booking.new(valid_attributes(check_in: Date.new(2026, 1, 4))) # dimanche
    assert booking.invalid?
    assert booking.errors[:check_in].any?
  end

  test "check_out must be a saturday" do
    booking = Booking.new(valid_attributes(check_out: Date.new(2026, 1, 18))) # dimanche
    assert booking.invalid?
    assert booking.errors[:check_out].any?
  end

  test "check_out must come after check_in" do
    booking = Booking.new(valid_attributes(check_in: Date.new(2026, 1, 17), check_out: Date.new(2026, 1, 3)))
    assert booking.invalid?
    assert booking.errors[:check_out].any?
  end

  test "guests_count must be positive when present" do
    assert Booking.new(valid_attributes(guests_count: nil)).valid?
    assert Booking.new(valid_attributes(guests_count: 0)).invalid?
  end

  test "generates a token on create" do
    booking = Booking.create!(valid_attributes)
    assert booking.token.present?
  end

  test "defaults to pending status" do
    assert Booking.new.pending?
  end

  test "computes nights, weeks and full name" do
    booking = Booking.new(valid_attributes)
    assert_equal 14, booking.nights
    assert_equal 2, booking.weeks
    assert_equal "Jean Dupont", booking.full_name
  end

  test "blocking scope returns only confirmed bookings" do
    pending = Booking.create!(valid_attributes)
    confirmed = Booking.create!(valid_attributes(email: "autre@example.com", status: :confirmed))
    assert_includes Booking.blocking, confirmed
    assert_not_includes Booking.blocking, pending
  end

  test "rejects confirmation when overlapping another confirmed booking" do
    Booking.create!(valid_attributes(status: :confirmed))
    conflict = Booking.new(valid_attributes(email: "b@example.com", status: :confirmed))
    assert conflict.invalid?
    assert_includes conflict.errors[:base].join, "chevauche"
  end

  test "allows back-to-back confirmed bookings (same saturday boundary)" do
    Booking.create!(valid_attributes(status: :confirmed)) # 3-17 jan.
    nextone = Booking.new(valid_attributes(
      check_in:  Date.new(2026, 1, 17),
      check_out: Date.new(2026, 1, 31),
      email:     "b@example.com",
      status:    :confirmed
    ))
    assert nextone.valid?, nextone.errors.full_messages.to_sentence
  end

  test "pending overlapping requests stay allowed" do
    Booking.create!(valid_attributes(status: :pending))
    other = Booking.new(valid_attributes(email: "b@example.com", status: :pending))
    assert other.valid?
  end
end
