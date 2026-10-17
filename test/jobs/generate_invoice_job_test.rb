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

  def blob_ids
    @booking.reload.invoices.ordered.map { |i| i.pdf.blob_id }
  end

  test "creates the deposit AND balance invoices with their PDF attached" do
    GenerateInvoiceJob.perform_now(@booking)
    @booking.reload
    assert_equal 2, @booking.invoices.count

    deposit = @booking.deposit_invoice
    balance = @booking.balance_invoice
    assert_equal 66_000, deposit.amount_cents
    # Solde = total − arrhes facturées, même non encore réglées.
    assert_equal 248_560, balance.amount_cents
    assert deposit.pdf.attached?
    assert balance.pdf.attached?
    assert_equal "application/pdf", deposit.pdf.content_type
    assert deposit.pdf_fingerprint.present?
  end

  test "is idempotent : a second run without changes creates nothing and keeps the same PDFs" do
    GenerateInvoiceJob.perform_now(@booking)
    before = blob_ids
    assert_no_difference "Invoice.count" do
      GenerateInvoiceJob.perform_now(@booking)
    end
    assert_equal before, blob_ids, "PDF inchangés tant que le contenu n'a pas changé"
  end

  test "regenerates the PDFs when something printed on them changes" do
    GenerateInvoiceJob.perform_now(@booking)
    before = blob_ids
    @booking.update_columns(last_name: "Durand")
    GenerateInvoiceJob.perform_now(@booking)
    assert_not_equal before, blob_ids
  end

  test "force: true regenerates unlocked PDFs even without changes" do
    GenerateInvoiceJob.perform_now(@booking)
    before = blob_ids
    GenerateInvoiceJob.perform_now(@booking, force: true)
    assert_not_equal before, blob_ids
  end

  test "a paid deposit invoice is never touched again (amount and PDF), the balance still is" do
    GenerateInvoiceJob.perform_now(@booking)
    deposit = @booking.deposit_invoice
    balance = @booking.balance_invoice
    deposit.mark_received!(on: Date.new(2025, 12, 5))
    deposit_blob = deposit.reload.pdf.blob_id
    balance_blob = balance.reload.pdf.blob_id

    # L'admin change le montant des arrhes sur la réservation après paiement.
    @booking.update_columns(deposit_cents: 70_000)
    GenerateInvoiceJob.perform_now(@booking)

    deposit.reload
    balance.reload
    assert_equal 66_000, deposit.amount_cents, "montant de la facture payée figé"
    assert_equal deposit_blob, deposit.pdf.blob_id, "PDF de la facture payée figé"
    assert_equal 248_560, balance.amount_cents, "solde = total − arrhes facturées (66 000), pas − 70 000"
    assert_not_equal balance_blob, balance.pdf.blob_id, "le PDF du solde mentionne désormais « réglée le »"
  end

  test "a paid invoice refuses any amount change" do
    GenerateInvoiceJob.perform_now(@booking)
    deposit = @booking.deposit_invoice
    deposit.mark_received!
    assert_not deposit.update(amount_cents: 1)
    assert_match(/déjà payée/, deposit.errors.full_messages.to_sentence)
  end
end
