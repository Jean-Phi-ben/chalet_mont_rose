# Identité de la société (Chalet Mont Rose SARL) lue dans l'environnement :
# source unique pour le contrat, les factures, les emails et les mentions légales.
# Aucun repli fictif : une donnée absente est vide (et le contrat refuse d'être
# généré si l'essentiel manque, cf. #ready?).
module CompanyIdentity
  DEFAULT_LEGAL_NAME = "Chalet Mont Rose SARL".freeze
  DEFAULT_EMAIL      = "chaletmontrose74@gmail.com".freeze
  DEFAULT_PHONE      = "+33 6 89 06 40 57".freeze

  module_function

  def legal_name     = ENV["COMPANY_LEGAL_NAME"].presence || DEFAULT_LEGAL_NAME
  def address        = ENV["COMPANY_ADDRESS"].to_s.strip
  def siret          = ENV["COMPANY_SIRET"].to_s.strip
  def vat_number     = ENV["COMPANY_VAT_NUMBER"].to_s.strip
  def capital        = ENV["COMPANY_CAPITAL"].to_s.strip
  def rcs            = ENV["COMPANY_RCS"].to_s.strip
  def representative = ENV["COMPANY_REPRESENTATIVE"].to_s.strip
  def email          = ENV["COMPANY_EMAIL"].presence || DEFAULT_EMAIL
  def phone          = ENV["COMPANY_PHONE"].presence || DEFAULT_PHONE

  # Médiateur de la consommation (obligatoire pour un professionnel) : à renseigner.
  def mediator_name    = ENV["MEDIATOR_NAME"].to_s.strip
  def mediator_address = ENV["MEDIATOR_ADDRESS"].to_s.strip
  def mediator_url     = ENV["MEDIATOR_URL"].to_s.strip

  # Le minimum pour engager la société dans un contrat ou une facture.
  def ready?
    address.present? && siret.present?
  end

  def missing
    { "COMPANY_ADDRESS" => address, "COMPANY_SIRET" => siret }.filter_map { |k, v| k if v.blank? }
  end

  # « Chalet Mont Rose SARL au capital de 1 000 € · RCS Annecy 123 456 789 · SIRET … · TVA … »
  def legal_line
    parts = [ legal_name ]
    parts << "au capital de #{capital}" if capital.present?
    parts << "RCS #{rcs}" if rcs.present?
    parts << "SIRET #{siret}" if siret.present?
    parts << "TVA #{vat_number}" if vat_number.present?
    parts.join(" · ")
  end
end
