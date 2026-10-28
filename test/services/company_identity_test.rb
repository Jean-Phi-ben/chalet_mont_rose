require "test_helper"

class CompanyIdentityTest < ActiveSupport::TestCase
  test "legal line assembles only the parts that are configured" do
    saved = ENV.to_h.slice("COMPANY_CAPITAL", "COMPANY_RCS", "COMPANY_VAT_NUMBER")
    ENV["COMPANY_CAPITAL"] = "1 000 €"
    ENV["COMPANY_RCS"] = "Annecy 123 456 789"
    ENV["COMPANY_VAT_NUMBER"] = ""
    line = CompanyIdentity.legal_line
    assert_match "Chalet Mont Rose SARL · au capital de 1 000 € · RCS Annecy 123 456 789 · SIRET", line
    assert_no_match(/TVA/, line)
  ensure
    saved.each { |k, v| ENV[k] = v }
  end
end
