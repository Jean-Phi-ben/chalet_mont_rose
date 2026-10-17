require "test_helper"

class ContractPdfTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 5, 9), check_out: Date.new(2026, 5, 16),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 150_000, deposit_cents: 45_000
    )
    @contract = Contract.create!(
      booking: @booking, status: :sent, sent_at: Time.current,
      signer_first_name: "Léa", signer_last_name: "Martin", signer_email: "lea@example.com"
    )
  end

  test "renders a PDF for a sent (unsigned) contract from the current template" do
    pdf = ContractPdf.render(@contract)
    assert pdf.start_with?("%PDF"), "doit produire un PDF"
  end

  test "a signed contract is rendered from its frozen text, never recomputed" do
    text = ContractTemplate.canonical_text(@booking, @contract)
    @contract.update_columns(status: Contract.statuses[:signed], signed_at: Time.current,
                             signed_ip: "1.2.3.4", signed_user_agent: "UA",
                             canonical_text: text, template_version: "1.1",
                             document_hash: "x" * 64)

    # Minitest 6 n'embarque plus minitest/mock : remplacement temporaire manuel.
    original = ContractTemplate.method(:canonical_text)
    ContractTemplate.define_singleton_method(:canonical_text) { |*| raise "le texte d'un contrat signé ne doit pas être recalculé" }
    begin
      pdf = ContractPdf.render(@contract.reload)
      assert pdf.start_with?("%PDF")
    ensure
      ContractTemplate.define_singleton_method(:canonical_text, original)
    end
  end
end
