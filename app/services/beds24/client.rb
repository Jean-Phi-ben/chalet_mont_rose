module Beds24
  # Client minimal de l'API Beds24 v2 (https://api.beds24.com/v2).
  #
  # Authentification : le refreshToken (BEDS24_REFRESH_TOKEN) sert à obtenir un jeton
  # d'accès valable 24 h (GET /authentication/token, en-tête `refreshToken`), mis en cache
  # 23 h. Le refreshToken expire après 30 jours sans usage : la poussée quotidienne le
  # garde vivant. Quota : 100 crédits par 5 minutes pour tout le compte.
  class Client
    class Error < StandardError; end
    class AuthError < Error; end

    TOKEN_CACHE_KEY = "beds24/access_token".freeze
    TOKEN_TTL       = 23.hours
    CALENDAR_CHUNK  = 100 # plages par requête d'écriture

    # Échange un code d'invitation (Beds24 > Settings > Apps & Integrations > API) contre
    # un couple token / refreshToken. À faire une seule fois ; le refreshToken va dans l'env.
    def self.setup(invite_code, base: Config.api_base)
      response = build_connection(base).get("authentication/setup") { |req| req.headers["code"] = invite_code.to_s.strip }
      raise AuthError, "setup refusé (#{response.status}) : #{error_message(response.body)}" unless response.success?

      response.body.slice("token", "refreshToken", "expiresIn")
    end

    def self.build_connection(base)
      base = "#{base}/" unless base.end_with?("/")
      Faraday.new(url: base, headers: { "Accept" => "application/json", "User-Agent" => "ChaletMontRose/1" }) do |f|
        f.request  :json
        f.response :json, content_type: /\bjson$/
        f.options.timeout = 30
        f.adapter Faraday.default_adapter
      end
    end

    def self.error_message(body)
      body.is_a?(Hash) ? (body["error"] || body["message"] || body.to_s)[0, 300] : body.to_s[0, 300]
    end

    def initialize(refresh_token: Config.refresh_token, base: Config.api_base, connection: nil)
      raise AuthError, "BEDS24_REFRESH_TOKEN manquant" if refresh_token.blank?

      @refresh_token = refresh_token
      @http = connection || self.class.build_connection(base)
    end

    def properties
      get("properties", includeAllRooms: true).fetch("data", [])
    end

    def calendar(room_id:, from:, to:)
      get("inventory/rooms/calendar", roomId: room_id, startDate: from.iso8601, endDate: to.iso8601,
                                      includePrices: true, includeMinStay: true, includeMaxStay: true,
                                      includeNumAvail: true, includeOverride: true).fetch("data", [])
    end

    # entries : tableau de hashes { from:, to:, price1:, price2:, minStay:, maxStay:, numAvail:, override: }.
    # Renvoie le nombre de plages écrites ; lève Error au premier refus.
    def write_calendar(room_id:, entries:)
      entries.each_slice(CALENDAR_CHUNK) do |chunk|
        results = post("inventory/rooms/calendar", [ { roomId: room_id, calendar: chunk } ])
        failed = Array(results).reject { |r| r.is_a?(Hash) && r["success"] }
        raise Error, "écriture calendrier refusée : #{failed.map { |r| self.class.error_message(r.is_a?(Hash) ? (r['errors'] || r) : r) }.join(' | ')}" if failed.any?
      end
      entries.size
    end

    private

    def get(path, params = {})
      request(:get, path, params: params)
    end

    def post(path, body)
      request(:post, path, body: body)
    end

    def request(method, path, params: nil, body: nil, retried: false)
      response = @http.run_request(method, path, body, { "token" => access_token }) do |req|
        req.params.update(params) if params
      end
      log_credits(response)

      if response.status == 401 && !retried
        Rails.cache.delete(TOKEN_CACHE_KEY)
        return request(method, path, params: params, body: body, retried: true)
      end
      raise Error, "Beds24 #{method.upcase} #{path} → #{response.status} : #{self.class.error_message(response.body)}" unless response.success?

      response.body
    rescue Faraday::Error => e
      raise Error, "Beds24 (transport) : #{e.message}"
    end

    def access_token
      Rails.cache.fetch(TOKEN_CACHE_KEY, expires_in: TOKEN_TTL) { fetch_access_token }
    end

    def fetch_access_token
      response = @http.get("authentication/token") { |req| req.headers["refreshToken"] = @refresh_token }
      raise AuthError, "jeton refusé (#{response.status}) : #{self.class.error_message(response.body)}" unless response.success?

      response.body.fetch("token")
    rescue Faraday::Error => e
      raise AuthError, "Beds24 (transport) : #{e.message}"
    end

    def log_credits(response)
      remaining = response.headers["x-five-min-limit-remaining"]
      return if remaining.blank?

      Rails.logger.warn("Beds24 : plus que #{remaining} crédits sur 5 min") if remaining.to_i < 15
    end
  end
end
