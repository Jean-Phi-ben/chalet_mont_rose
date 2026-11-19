module Beds24
  # Prix de nuit envoyé à Airbnb à partir du prix direct d'une semaine.
  #
  # Airbnb prélève des frais hôte `f` sur le sous-total (nuits + ménage). Trois objectifs :
  #   :payout          — préserver le versement brut        : P / (1 − f)
  #   :net_ht          — préserver le net HT (SARL assujettie, TVA sur la commission
  #                      autoliquidée)                      : P / (1 − f·(1 + τ))   τ = TVA hébergement
  #   :no_vat_recovery — TVA 20 % sur la commission non récupérable : P / (1 − f·1,2)
  # Le ménage (forfait par semaine sur le site, BookingSetting#cleaning_fee_cents) est intégré au
  # prix de nuit : les frais de ménage Airbnb sont comptés une fois par séjour, alors que le site
  # les facture par semaine (2 semaines = 2 forfaits) ; les frais hôte s'y appliquent aussi.
  # La taxe de séjour n'y figure pas : Airbnb la collecte et la reverse lui-même.
  module AirbnbPricing
    module_function

    MODES = %i[payout net_ht no_vat_recovery].freeze
    VAT_ON_FEE = BigDecimal("0.20")

    def coefficient(mode = Config.airbnb_mode, host_fee: Config.airbnb_host_fee,
                    vat_on_stay: BigDecimal(Booking::VAT_RATES.fetch(:accommodation).to_s) / 100)
      f = BigDecimal(host_fee.to_s)
      case mode.to_sym
      when :payout          then 1 / (1 - f)
      when :net_ht          then 1 / (1 - f * (1 + vat_on_stay))
      when :no_vat_recovery then 1 / (1 - f * (1 + VAT_ON_FEE))
      else raise ArgumentError, "mode Airbnb inconnu : #{mode.inspect} (attendu : #{MODES.join(', ')})"
      end
    end

    # Prix de nuit Airbnb en euros entiers (arrondi au-dessus) pour une semaine à `week_cents`,
    # ménage de la semaine (`cleaning_week_cents`) compris.
    def nightly_euros(week_cents, cleaning_week_cents:, mode: Config.airbnb_mode)
      week = (BigDecimal(week_cents.to_s) + BigDecimal(cleaning_week_cents.to_s)) * coefficient(mode)
      (week / 7 / 100).ceil.to_i
    end

    # Prix de nuit direct en euros entiers (référence, price1).
    def direct_nightly_euros(week_cents)
      (BigDecimal(week_cents.to_s) / 7 / 100).ceil.to_i
    end
  end
end
