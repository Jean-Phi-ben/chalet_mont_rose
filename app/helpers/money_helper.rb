module MoneyHelper
  NBSP = " ".freeze

  # Affiche un montant stocké en centimes au format français : « 5 800 € », « 1 234,50 € »,
  # avec des espaces insécables (pas de retour à la ligne entre les milliers ni avant le €).
  def money(cents, unit: "€")
    return "—" if cents.nil?

    precision = (cents % 100).zero? ? 0 : 2
    number_to_currency(
      cents / 100.0,
      unit: unit,
      format: "%n#{NBSP}%u",
      separator: ",",
      delimiter: NBSP,
      precision: precision
    )
  end
end
