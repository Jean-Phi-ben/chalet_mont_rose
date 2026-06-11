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

  # --- blocked / transition dates ----------------------------------------------

  test "blocked_dates_between excludes check_in and check_out (transition days)" do
    Booking.create!(valid_attributes(
      check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17),
      status: :confirmed
    ))
    blocked = Booking.blocked_dates_between(Date.new(2026, 1, 1), Date.new(2026, 1, 31))

    # Nuits intermédiaires bloquées (Sun à Fri).
    (Date.new(2026, 1, 11)..Date.new(2026, 1, 16)).each do |d|
      assert blocked.include?(d), "#{d} devrait être bloqué (nuit intermédiaire)"
    end

    # Samedis de check_in / check_out NON bloqués — ils sont des jours de transition.
    refute blocked.include?(Date.new(2026, 1, 10)), "Sat check_in doit rester cliquable"
    refute blocked.include?(Date.new(2026, 1, 17)), "Sat check_out doit rester cliquable"
  end

  test "transition_dates_between returns the Saturdays of check_in and check_out" do
    Booking.create!(valid_attributes(
      check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17),
      status: :confirmed
    ))
    transitions = Booking.transition_dates_between(Date.new(2026, 1, 1), Date.new(2026, 1, 31))
    assert_includes transitions, Date.new(2026, 1, 10), "check_in inclus"
    assert_includes transitions, Date.new(2026, 1, 17), "check_out inclus"
  end

  test "can book the week BEFORE an existing booking (turnover on check_in Saturday)" do
    # Booking existant : Sat 10 → Sat 17
    Booking.create!(valid_attributes(
      check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17),
      status: :confirmed
    ))
    # Nouvelle résa qui FINIT le Sat 10 (check_in de l'autre) → doit passer
    refute Booking.confirmed_overlap?(Date.new(2026, 1, 3), Date.new(2026, 1, 10)),
           "Réserver [Sat 3 → Sat 10) doit être possible même si Sat 10 = check_in d'une autre résa"
  end
end
