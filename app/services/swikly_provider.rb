# Façade autour de l'API Swikly V2 pour la caution (Security Deposit).
# Doc : https://api.sandbox.swikly.com/v1 (sandbox) — la modélisation expose
# des Requests avec différentes "Operations" (deposit, no-show, payment).
# Tant que SWIKLY_API_KEY ou SWIKLY_ACCOUNT_ID n'est pas renseigné, on bascule
# en mode stub pour pouvoir tester localement sans appeler Swikly.
class SwiklyProvider
  RequestResult = Struct.new(:provider_request_id, :deposit_url, keyword_init: true)

  class Error < StandardError; end

  SANDBOX_BASE    = "https://api.sandbox.swikly.com/v1".freeze
  PRODUCTION_BASE = "https://api.swikly.com/v1".freeze

  def self.enabled?
    ENV["SWIKLY_API_KEY"].present? && ENV["SWIKLY_ACCOUNT_ID"].present?
  end

  def self.test_mode?
    ENV["SWIKLY_TEST_MODE"].to_s.downcase != "false"
  end

  def self.api_base
    return ENV["SWIKLY_API_BASE"] if ENV["SWIKLY_API_BASE"].present?
    test_mode? ? SANDBOX_BASE : PRODUCTION_BASE
  end

  def self.create_request(booking)
    enabled? ? new.create_request(booking) : stub_create(booking)
  end

  # Vérifie l'authenticité d'un webhook Swikly.
  # Header : Swikly-Signature: t=<timestamp>,sha256=<hex>
  # Signature = HMAC-SHA256(account_secret, "#{timestamp}.#{raw_body}")
  def self.verify_signature(raw_body, signature_header)
    return true unless enabled?
    return false if signature_header.blank?

    parts = signature_header.to_s.split(",").map { |p| p.strip.split("=", 2) }.to_h
    timestamp = parts["t"]
    received  = parts["sha256"]
    return false if timestamp.blank? || received.blank?

    expected = OpenSSL::HMAC.hexdigest("SHA256", ENV["SWIKLY_API_SECRET"].to_s, "#{timestamp}.#{raw_body}")
    ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  # --- Mode stub --------------------------------------------------------------

  def self.stub_create(booking)
    rid = "stub_swik_#{booking.id}_#{booking.token[0, 6]}"
    RequestResult.new(
      provider_request_id: rid,
      deposit_url: "about:blank?stub_caution=#{booking.token}"
    )
  end

  # --- Implémentation réelle (API Swikly V2) ----------------------------------

  def create_request(booking)
    response = http.post("accounts/#{account_id}/requests") do |req|
      req.headers["Authorization"] = "Bearer #{ENV['SWIKLY_API_KEY']}"
      req.headers["Accept"]        = "application/json"
      req.headers["Content-Type"]  = "application/json"
      req.headers["User-Agent"]    = "ChaletMontRose/1"
      req.body = payload_for(booking).to_json
    end

    unless response.success?
      raise Error, "Swikly #{response.status} : #{extract_message(response.body)}"
    end

    body = JSON.parse(response.body)
    request_obj = body["request"] || {}
    deposit_obj = request_obj["deposit"] || {}

    RequestResult.new(
      provider_request_id: deposit_obj["id"] || request_obj["id"],
      deposit_url:         request_obj["link"]
    )
  rescue Faraday::Error => e
    raise Error, "Swikly (transport) : #{e.message}"
  end

  private

  def http
    # Trailing slash impératif sur le base URL pour que Faraday concatène
    # correctement le path "accounts/..." sans écraser le préfixe /v1.
    base = self.class.api_base.to_s
    base = "#{base}/" unless base.end_with?("/")
    @http ||= Faraday.new(url: base) { |f| f.adapter Faraday.default_adapter }
  end

  def account_id
    ENV["SWIKLY_ACCOUNT_ID"].to_s
  end

  def payload_for(booking)
    {
      description: "Caution séjour Chalet Mont Rose — #{I18n.l(booking.check_in)} → #{I18n.l(booking.check_out)}",
      language:    "fr",
      customId:    booking.token,
      firstName:   booking.first_name,
      lastName:    booking.last_name,
      email:       booking.email,
      phoneNumber: format_phone(booking.phone),
      deposit: {
        startDate: booking.check_in.iso8601,
        endDate:   booking.check_out.iso8601,
        amount:    caution_amount_cents(booking)
      },
      callbacks: {
        requestSecured: callback_url
      }.compact,
      redirectUrl: redirect_url,
      sendEmail:   false,   # on envoie nous-même via notre mailer
      sendSms:     false
    }.compact
  end

  # Swikly exige un préfixe pays type +33. Si l'utilisateur a saisi un n° FR
  # sans préfixe (commence par 0), on le réécrit en +33.
  def format_phone(phone)
    return nil if phone.blank?
    digits = phone.to_s.delete(" .-")
    return digits if digits.start_with?("+")
    return "+33#{digits[1..]}" if digits.start_with?("0") && digits.size == 10
    digits
  end

  def callback_url
    return nil if ENV["SWIKLY_CALLBACK_URL"].blank?
    ENV["SWIKLY_CALLBACK_URL"]
  end

  def redirect_url
    ENV["SWIKLY_REDIRECT_URL"].presence
  end

  def caution_amount_cents(booking)
    explicit = ENV["CAUTION_AMOUNT"].to_i
    return explicit * 100 if explicit.positive?
    ((booking.total_price_cents.to_i * 0.30).round).clamp(50_000, 200_000)
  end

  def extract_message(body)
    parsed = JSON.parse(body.to_s)
    msg = parsed["message"]
    errs = parsed["errors"]
    return msg if errs.blank?
    "#{msg} — #{errs.flat_map { |k, v| Array(v).map { |m| "#{k}: #{m}" } }.join(' · ')}"
  rescue StandardError
    body.to_s[0, 300]
  end
end
