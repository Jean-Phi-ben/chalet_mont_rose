require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      guests_count: 4,
      accommodation_cents: 220_000, cleaning_fee_cents: 80_000, tourist_tax_cents: 14_560,
      total_price_cents: 314_560, deposit_cents: 66_000
    )
  end

  test "from_booking builds a deposit invoice and a balance invoice" do
    deposit, balance = Invoice.from_booking(@booking)
    deposit.save!
    balance.save!

    assert deposit.kind_deposit?
    assert_equal 66_000, deposit.amount_cents
    assert balance.kind_balance?
    # Arrhes non encore reçues → solde = total séjour (rien à déduire).
    assert_equal 314_560, balance.amount_cents
    assert_equal Date.current, deposit.issued_on
  end

  test "balance amount resyncs to (total − deposit) once the deposit is marked received" do
    Invoice.from_booking(@booking).each(&:save!)
    deposit = @booking.deposit_invoice
    balance = @booking.balance_invoice
    assert_equal 314_560, balance.amount_cents

    deposit.mark_received!
    assert_equal 248_560, balance.reload.amount_cents  # 314 560 − 66 000
  end

  test "balance amount resyncs back to the full total when the deposit is reverted" do
    Invoice.from_booking(@booking).each(&:save!)
    deposit = @booking.deposit_invoice
    deposit.mark_received!
    deposit.mark_awaiting!
    assert_equal 314_560, @booking.balance_invoice.reload.amount_cents
  end

  test "auto-numbers invoices sequentially per year" do
    Invoice.from_booking(@booking).each(&:save!)
    numbers = @booking.invoices.order(:id).pluck(:number)

    year = Date.current.year
    assert_equal "CMR-#{year}-0001", numbers.first
    assert_equal "CMR-#{year}-0002", numbers.last
  end

  test "mark_received! updates status and date" do
    deposit, balance = Invoice.from_booking(@booking)
    deposit.save!
    balance.save!

    deposit.mark_received!
    assert deposit.payment_received?
    assert_equal Date.current, deposit.received_on
  end
end
