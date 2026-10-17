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
    # Solde = total − arrhes facturées (dès l'émission, réglées ou non).
    assert_equal 248_560, balance.amount_cents
    assert_equal Date.current, deposit.issued_on
  end

  test "balance amount does not depend on the deposit payment status" do
    Invoice.from_booking(@booking).each(&:save!)
    deposit = @booking.deposit_invoice
    balance = @booking.balance_invoice
    assert_equal 248_560, balance.amount_cents  # 314 560 − 66 000

    deposit.mark_received!
    assert_equal 248_560, balance.reload.amount_cents
    deposit.mark_awaiting!
    assert_equal 248_560, balance.reload.amount_cents
  end

  test "locked? once paid or when invoicing is archived" do
    Invoice.from_booking(@booking).each(&:save!)
    deposit = @booking.deposit_invoice
    assert_not deposit.locked?
    deposit.mark_received!
    assert deposit.locked?

    balance = @booking.balance_invoice
    assert_not balance.locked?
    @booking.archive_invoicing!
    assert balance.reload.locked?
  end

  test "auto-numbers invoices sequentially per year" do
    Invoice.from_booking(@booking).each(&:save!)
    numbers = @booking.invoices.order(:id).pluck(:number)

    year = Date.current.year
    assert_equal "CMR-#{year}-0001", numbers.first
    assert_equal "CMR-#{year}-0002", numbers.last
  end

  test "due_on: deposit 7 days after issue, balance 10 days before arrival" do
    deposit = @booking.invoices.create!(kind: :deposit, amount_cents: 66_000, issued_on: Date.new(2025, 11, 20))
    balance = @booking.invoices.create!(kind: :balance, amount_cents: 248_560, issued_on: Date.new(2025, 11, 20))

    assert_equal Date.new(2025, 11, 27), deposit.due_on
    assert_equal Date.new(2025, 12, 24), balance.due_on  # arrivée le 3 janvier 2026

    assert deposit.overdue?(Date.new(2025, 11, 28))
    assert_not deposit.overdue?(Date.new(2025, 11, 27))
    deposit.mark_received!(on: Date.new(2025, 11, 25))
    assert_not deposit.overdue?(Date.new(2025, 12, 31))
  end

  test "a paid invoice always gets a payment date" do
    invoice = @booking.invoices.create!(kind: :deposit, amount_cents: 66_000)
    invoice.update!(status: :received)   # comme depuis l'admin, sans saisir de date
    assert_equal Date.current, invoice.received_on

    invoice.update!(received_on: Date.new(2025, 12, 2))
    assert_equal Date.new(2025, 12, 2), invoice.reload.received_on  # une date saisie n'est pas écrasée
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
