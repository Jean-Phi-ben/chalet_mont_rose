require "test_helper"

class ContractTemplateTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 12, 19), check_out: Date.new(2027, 1, 2),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com", guests_count: 6,
      accommodation_cents: 1_840_000, cleaning_fee_cents: 80_000, tourist_tax_cents: 18_200,
      total_price_cents: 1_938_200, deposit_cents: 552_000, status: :confirmed
    )
    @contract = Contract.new(booking: @booking, signer_first_name: "Léa", signer_last_name: "Martin",
                             signer_email: "lea@example.com", signer_address: "1 rue des Alpes, 74170 Saint-Gervais")
    @text = ContractTemplate.canonical_text(@booking, @contract)
  end

  test "version 1.2, nine sections, deterministic" do
    assert_match(/\AVersion|CONTRAT DE LOCATION SAISONNIÈRE — Chalet Mont Rose SARL\nVersion du contrat : 1\.2/, @text)
    assert_equal 9, ContractTemplate.sections(@booking, @contract).size
    assert_equal @text, ContractTemplate.canonical_text(@booking, @contract)
  end

  test "dates in French, departure on the real check-out date, plurals and amounts formatted" do
    assert_match "Arrivée : samedi 19 décembre 2026 à partir de 16 h.", @text
    assert_match "Départ : samedi 2 janvier 2027 avant 10 h.", @text
    assert_match "2 semaines, soit 14 nuits", @text
    assert_match "6 personnes", @text
    assert_match "19 382,00 €", @text
    assert_match "Arrhes : 5 520,00 € (30 % de l'hébergement)", @text
    assert_match "Solde : 13 862,00 €", @text
    assert_match "#{Invoice::BALANCE_DUE_DAYS} jours avant l'arrivée", @text
  end

  test "legal content: arrhes only (art. 1590), caution amount, mediation, no outdated wording" do
    assert_no_match(/acompte/i, @text)
    assert_match "article 1590 du Code civil", @text
    assert_match "le double des arrhes", @text
    assert_no_match(/totalité du séjour reste due/, @text)
    assert_no_match(/bon père de famille/, @text)
    assert_match "Une caution de 2 000,00 €", @text # 30 % de 19 382 € borné à 2 000 €
    assert_match "médiateur de la consommation", @text
    assert_no_match(/tribunaux du ressort/, @text)
  end

  test "company identity comes from CompanyIdentity, without fictitious fallback" do
    assert_match "SIRET #{CompanyIdentity.siret}", @text
    assert_match CompanyIdentity.address, @text
    assert_no_match(/SIRET n\.c\./, @text)
    assert ContractTemplate.ready?
  end

  test "SendContractJob refuses to generate a contract without the company's address or SIRET" do
    original = ENV["COMPANY_SIRET"]
    ENV["COMPANY_SIRET"] = ""
    assert_not ContractTemplate.ready?
    error = assert_raises(RuntimeError) { SendContractJob.perform_now(@booking) }
    assert_match "COMPANY_SIRET", error.message
    assert_nil @booking.reload.contract
  ensure
    ENV["COMPANY_SIRET"] = original
  end
end
