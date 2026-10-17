require "test_helper"

class BookingPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(email_address: "admin@example.com", password: "password")
    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 10),
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      total_price_cents: 100_000, deposit_cents: 30_000
    )
  end

  def policy(booking = @booking) = BookingPolicy.new(@admin, booking)

  test "confirm? only for a pending booking" do
    assert policy.confirm?
    %i[confirmed rejected cancelled].each do |status|
      @booking.update_columns(status: Booking.statuses[status])
      assert_not policy(@booking.reload).confirm?, "pas de (re)confirmation d'une réservation #{status}"
    end
  end

  test "destroy? refused for a confirmed booking, an invoiced one, or a signed contract" do
    assert policy.destroy?

    @booking.update_columns(status: Booking.statuses[:confirmed])
    assert_not policy(@booking.reload).destroy?

    @booking.update_columns(status: Booking.statuses[:rejected])
    @booking.invoices.create!(kind: :deposit, amount_cents: 30_000)
    assert_not policy(@booking.reload).destroy?

    @booking.invoices.destroy_all
    @booking.create_contract!(status: :signed, signer_email: "j@example.com")
    assert_not policy(@booking.reload).destroy?
  end
end
