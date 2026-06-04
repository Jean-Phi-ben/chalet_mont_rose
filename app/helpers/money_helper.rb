module MoneyHelper
  # Affiche un montant stocké en centimes au format français : "5 800 €", "1 234,50 €".
  def money(cents, unit: "€")
    return "—" if cents.nil?

    precision = (cents % 100).zero? ? 0 : 2
    number_to_currency(
      cents / 100.0,
      unit: unit,
      format: "%n %u",
      separator: ",",
      delimiter: " ",
      precision: precision
    )
  end
end
