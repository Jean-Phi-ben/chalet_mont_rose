require "test_helper"

class CautionTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 6, 6), check_out: Date.new(2026, 6, 13),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 150_000, deposit_cents: 45_000
    )
  end

  test "default status is pending" do
    c = Caution.create!(booking: @booking, amount_cents: 100_000)
    assert c.status_pending?
  end

  test "depositable? requires pending status and deposit_url" do
    c = Caution.create!(booking: @booking, amount_cents: 100_000, deposit_url: "https://x")
    assert c.depositable?
    c.update!(deposit_url: nil)
    assert_not c.depositable?
    c.update!(status: :accepted, deposit_url: "https://x")
    assert_not c.depositable?
  end

  test "one caution per booking" do
    Caution.create!(booking: @booking, amount_cents: 100_000)
    dup = Caution.new(booking: @booking, amount_cents: 100_000)
    assert_not dup.save
  end
end
