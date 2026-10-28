# Affichage du taux d'arrhes par défaut (Pricing.deposit_rate) : « 30 % », « 32,5 % ».
module PricingHelper
  def deposit_rate_label
    pct = (Pricing.deposit_rate * 100).round(1)
    "#{pct.to_s.sub(/\.0\z/, '').tr('.', ',')} %"
  end
end
