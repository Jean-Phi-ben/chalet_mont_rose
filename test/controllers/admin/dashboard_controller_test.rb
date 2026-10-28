require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Date.new(2025, 12, 1)
    sign_in_as(User.create!(email_address: "admin@example.com", password: "motdepasse"))

    @pending = Booking.create!(
      check_in: Date.new(2026, 2, 7), check_out: Date.new(2026, 2, 14),
      first_name: "Paul", last_name: "Attente", email: "paul@example.com",
      guests_count: 6, total_price_cents: 500_000, deposit_cents: 150_000
    )
    @confirmed = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      guests_count: 4, total_price_cents: 314_560, deposit_cents: 66_000, status: :confirmed
    )
    # Arrhes émises le 20/11 → échéance 27/11 dépassée ; solde dû le 31/12.
    @deposit = @confirmed.invoices.create!(kind: :deposit, amount_cents: 66_000, issued_on: Date.new(2025, 11, 20))
    @balance = @confirmed.invoices.create!(kind: :balance, amount_cents: 248_560, issued_on: Date.new(2025, 11, 20))
  end

  teardown { travel_back }

  test "dashboard lists bookings to validate, upcoming invoices with status and received invoices" do
    get admin_root_url
    assert_response :success

    assert_select "[data-dashboard-section=pending-bookings] a[href=?]", admin_booking_path(@pending), text: /Paul Attente/
    assert_select "[data-dashboard-section=pending-bookings]", text: /Jean Dupont/, count: 0

    assert_select "[data-dashboard-section=upcoming-invoices]" do
      assert_select "a[href=?] [data-invoice-state=overdue]", admin_invoice_path(@deposit), text: /27 novembre 2025/
      assert_select "a[href=?] [data-invoice-state=awaiting]", admin_invoice_path(@balance), text: /31 décembre 2025/
    end
    assert_select "[data-dashboard-section=received-invoices]", text: /Aucune facture encaissée/

    @deposit.mark_received!(on: Date.new(2025, 11, 26))
    get admin_root_url
    assert_select "[data-dashboard-section=received-invoices] a[href=?] [data-invoice-state=paid]",
                  admin_invoice_path(@deposit), text: /Payée le 26 novembre 2025/
    assert_select "[data-dashboard-section=upcoming-invoices] a[href=?]", admin_invoice_path(@deposit), count: 0
  end

  test "empty states" do
    Invoice.delete_all # une réservation facturée ne se détruit pas ; on vide à plat
    Booking.delete_all
    get admin_root_url
    assert_select "[data-dashboard-section=pending-bookings]", text: /Aucune demande en attente/
    assert_select "[data-dashboard-section=upcoming-invoices]", text: /Aucune facture en attente/
  end
end
