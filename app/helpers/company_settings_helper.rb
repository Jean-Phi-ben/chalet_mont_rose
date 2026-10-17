# Coordonnées de la société lues dans l'environnement (COMPANY_*), utilisées par les
# factures PDF (RIB, mentions légales) et le contrat. Sans elles, les documents générés
# sont incomplets : l'admin affiche alors un bandeau d'alerte.
module CompanySettingsHelper
  REQUIRED_COMPANY_SETTINGS = {
    "COMPANY_ACCOUNT_HOLDER" => "titulaire du compte",
    "COMPANY_IBAN"           => "IBAN",
    "COMPANY_BIC"            => "BIC",
    "COMPANY_ADDRESS"        => "adresse",
    "COMPANY_SIRET"          => "SIRET",
    "COMPANY_VAT_NUMBER"     => "n° de TVA",
    "COMPANY_CAPITAL"        => "capital social",
    "COMPANY_EMAIL"          => "email"
  }.freeze

  # Libellés des réglages absents, dans l'ordre ci-dessus ([] si tout est configuré).
  def missing_company_settings
    REQUIRED_COMPANY_SETTINGS.filter_map { |key, label| label if ENV[key].blank? }
  end
end
