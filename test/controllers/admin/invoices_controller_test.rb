require "test_helper"

class Admin::InvoicesControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  setup do
    travel_to Date.new(2025, 12, 1)
    @admin = User.create!(email_address: "admin@example.com", password: "password", admin: true)
    sign_in_as(@admin)

    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "j@example.com",
      guests_count: 4,
      accommodation_cents: 220_000, cleaning_fee_cents: 80_000, tourist_tax_cents: 14_560,
      total_price_cents: 314_560, deposit_cents: 66_000,
      status: :confirmed
    )
    Invoice.from_booking(@booking).each(&:save!)
    @deposit = @booking.deposit_invoice
    @balance = @booking.balance_invoice
  end

  teardown { travel_back }

  test "index lists bookings with their two invoice numbers, sorted by check_in" do
    other_booking = Booking.create!(
      check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      accommodation_cents: 100_000, total_price_cents: 147_280, deposit_cents: 30_000,
      status: :confirmed
    )
    Invoice.from_booking(other_booking).each(&:save!)

    get admin_invoices_url
    assert_response :success
    # Jean (3 jan.) avant Marie (4 juil.).
    assert response.body.index("Jean Dupont") < response.body.index("Marie Curie")
    # Deux numéros visibles pour Jean.
    assert_match @deposit.number, response.body
    assert_match @balance.number, response.body
  end

  test "index excludes bookings whose check_out is past" do
    travel_back
    get admin_invoices_url
    assert_response :success
    assert_no_match(/Jean Dupont/, response.body)
  end

  test "archived lists past bookings" do
    travel_back
    get archived_admin_invoices_url
    assert_response :success
    assert_match "Archives", response.body
    assert_match "Jean Dupont", response.body
  end

  test "index displays a link to the archives" do
    get admin_invoices_url
    assert_select "a[href=?]", archived_admin_invoices_path
  end

  test "show renders both invoices for the booking" do
    get admin_invoice_url(@deposit)
    assert_response :success
    assert_match @deposit.number, response.body
    assert_match @balance.number, response.body
  end

  test "mark_received flips the deposit invoice to received and regenerates both PDFs synchronously" do
    patch mark_received_admin_invoice_url(@deposit)
    assert_redirected_to admin_invoice_path(@deposit)

    @deposit.reload
    @balance.reload
    assert @deposit.payment_received?
    assert @deposit.pdf.attached?
    assert @balance.pdf.attached?
    # Solde recalculé : 314 560 − 66 000 = 248 560.
    assert_equal 248_560, @balance.amount_cents
  end

  test "mark_received flips the balance invoice to received" do
    patch mark_received_admin_invoice_url(@balance)
    assert_redirected_to admin_invoice_path(@balance)
    assert @balance.reload.payment_received?
  end

  test "mark_awaiting reverts a received invoice to awaiting" do
    @deposit.mark_received!
    patch mark_awaiting_admin_invoice_url(@deposit)
    assert_redirected_to admin_invoice_path(@deposit)
    assert @deposit.reload.payment_awaiting?
    assert_nil @deposit.received_on
  end

  test "update edits the received_on date" do
    @deposit.mark_received!
    patch admin_invoice_url(@deposit), params: { invoice: { received_on: "2026-02-10" } }
    assert_redirected_to admin_invoice_path(@deposit)
    assert_equal Date.new(2026, 2, 10), @deposit.reload.received_on
  end

  test "show displays the breakdown table with HT / quantity / TTC columns" do
    get admin_invoice_url(@deposit)
    assert_response :success
    assert_match "Montant HT",  response.body
    assert_match "Quantité",    response.body
    assert_match "Montant TTC", response.body
    assert_match "14 nuits",   response.body
    assert_match "2 sem.",     response.body
    assert_match "56 nuitées", response.body
  end

  test "show includes the per-line VAT column and the VAT total above Total séjour" do
    get admin_invoice_url(@deposit)
    assert_response :success
    assert_match "TVA", response.body
    assert_match "Total séjour", response.body
    # Une colonne TVA avec les taux par catégorie : 10 %, 20 %, 0 %.
    assert_match "10 %", response.body
    assert_match "20 %", response.body
    assert_match "0 %",  response.body
    assert_match "hébergement + ménage", response.body  # libellé du total TVA
    # Vue consolidée : ligne « Arrhes réglées » + « Solde à régler à J-10 ».
    assert_match "Arrhes réglées", response.body
    assert_match "Solde à régler à J-10", response.body
  end

  test "show on the balance invoice always shows the arrhes line, negative when paid" do
    @deposit.update!(status: :received, received_on: Date.new(2025, 12, 15))
    get admin_invoice_url(@balance)
    assert_response :success
    assert_match "Arrhes réglées le", response.body
    assert_match "Solde à régler à J-10", response.body
  end

  test "show on the balance invoice shows arrhes 0 € when deposit is not paid yet" do
    get admin_invoice_url(@balance)
    assert_response :success
    # Ligne « Arrhes réglées » présente avec 0 € tant que les arrhes ne sont pas reçues.
    assert_select "td", text: "Arrhes réglées"
    assert_match "Solde à régler à J-10", response.body
  end

  test "archive button appears only when both invoices are paid and locks editing" do
    get admin_invoice_url(@deposit)
    assert_select "form[action=?]", archive_admin_invoice_path(@deposit), count: 0

    @deposit.mark_received!
    @balance.mark_received!
    get admin_invoice_url(@deposit)
    assert_select "form[action=?]", archive_admin_invoice_path(@deposit)

    patch archive_admin_invoice_url(@deposit)
    assert_redirected_to admin_invoice_path(@deposit)
    assert @booking.reload.invoicing_archived?

    # Plus possible de modifier les paiements une fois archivé.
    patch mark_awaiting_admin_invoice_url(@deposit)
    assert @deposit.reload.payment_received?
  end
end
