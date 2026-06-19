require "test_helper"

class GenerateInvoiceJobTest < ActiveJob::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      guests_count: 4,
      accommodation_cents: 220_000, cleaning_fee_cents: 80_000, tourist_tax_cents: 14_560,
      total_price_cents: 314_560, deposit_cents: 66_000,
      status: :confirmed
    )
  end

  test "creates the deposit AND balance invoices with their PDF attached" do
    GenerateInvoiceJob.perform_now(@booking)
    @booking.reload
    assert_equal 2, @booking.invoices.count

    deposit = @booking.deposit_invoice
    balance = @booking.balance_invoice
    assert_equal 66_000, deposit.amount_cents
    # Arrhes non reçues à la création → solde = total séjour entier.
    assert_equal 314_560, balance.amount_cents
    assert deposit.pdf.attached?
    assert balance.pdf.attached?
    assert_equal "application/pdf", deposit.pdf.content_type
    assert_equal "application/pdf", balance.pdf.content_type
  end

  test "is idempotent : a second run re-attaches the PDFs without creating new invoices" do
    GenerateInvoiceJob.perform_now(@booking)
    assert_no_difference "Invoice.count" do
      GenerateInvoiceJob.perform_now(@booking)
    end
  end
end
