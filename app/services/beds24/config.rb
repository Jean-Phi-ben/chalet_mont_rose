module Beds24
  # Réglages Beds24 lus dans l'environnement (.env en dev, ~/.chalet_env en prod).
  module Config
    module_function

    API_BASE = "https://api.beds24.com/v2".freeze

    # Jeton de renouvellement (refreshToken) obtenu une fois avec `bin/rails beds24:setup[code]`.
    def refresh_token = ENV["BEDS24_REFRESH_TOKEN"].presence

    # Identifiant de la chambre Beds24 (le chalet), voir `bin/rails beds24:properties`.
    def room_id = ENV["BEDS24_ROOM_ID"].presence&.to_i

    # Rien n'est envoyé sans jeton ni chambre, ni depuis l'instance de staging.
    def enabled?
      refresh_token.present? && room_id.present? && ENV["STAGING"].blank?
    end

    def api_base = ENV["BEDS24_API_BASE"].presence || API_BASE

    # Objectif de la majoration Airbnb : :net_ht (défaut, SARL assujettie), :payout, :no_vat_recovery.
    def airbnb_mode = (ENV["BEDS24_AIRBNB_MODE"].presence || "net_ht").to_sym

    # Frais hôte Airbnb (part HT du sous-total), 15,5 % par défaut.
    def airbnb_host_fee = BigDecimal(ENV["BEDS24_AIRBNB_HOST_FEE"].presence || "0.155")

    # Séjour samedi → samedi : 7 nuits minimum, 21 nuits maximum par défaut.
    def min_stay_nights = 7
    def max_stay_nights = (ENV["BEDS24_MAX_STAY_NIGHTS"].presence || "21").to_i
  end
end
