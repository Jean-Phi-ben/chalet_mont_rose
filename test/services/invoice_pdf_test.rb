require "test_helper"

class InvoicePdfTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Zoë Łukasz", last_name: "Øyvind Ćwikła", email: "z@example.com",
      guests_count: 4,
      accommodation_cents: 220_000, cleaning_fee_cents: 80_000, tourist_tax_cents: 14_560,
      total_price_cents: 314_560, deposit_cents: 66_000, status: :confirmed
    )
    Invoice.from_booking(@booking).each(&:save!)
  end

  test "both invoices render with a client name outside Windows-1252" do
    @booking.invoices.each do |invoice|
      pdf = nil
      assert_nothing_raised { pdf = InvoicePdf.render(invoice) }
      assert pdf.start_with?("%PDF")
    end
  end
end
