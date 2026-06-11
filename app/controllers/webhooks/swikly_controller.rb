module Webhooks
  # Webhook Swikly V2 : notifications sur le cycle de vie d'une Request /
  # Deposit. Le header Swikly-Signature contient timestamp + HMAC-SHA256
  # signé avec l'account secret.
  #
  # Events traités (https://api.sandbox.swikly.com/v1) :
  #   - requestSecured : l'end-user a déposé sa caution
  #   - allPendingReclaimsCompleted : les reclaim ont été exécutés
  #   - allPendingRefundsCompleted  : tous les remboursements sont terminés
  class SwiklyController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    def create
      raw = request.raw_post
      unless SwiklyProvider.verify_signature(raw, request.headers["Swikly-Signature"])
        head :forbidden and return
      end

      payload = JSON.parse(raw)
      handle_event(payload["event"].to_s, payload)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def handle_event(event, payload)
      req = payload["request"] || {}
      caution = find_caution(req)
      return unless caution

      case event
      when "requestSecured"
        # L'opération "deposit" est passée en status Accepted.
        deposit = req["deposit"] || {}
        if deposit["status"].to_s.casecmp("Accepted").zero?
          caution.update!(status: :accepted, accepted_at: parse_time(deposit["acceptedAt"]) || Time.current)
        end
      when "allPendingReclaimsCompleted"
        caution.update!(status: :captured, captured_at: Time.current)
      when "allPendingRefundsCompleted"
        caution.update!(status: :released, released_at: Time.current)
      end
    end

    # On retrouve notre Caution soit par l'ID de l'opération deposit, soit
    # par l'ID de la request (selon ce qu'on a stocké à la création).
    def find_caution(req)
      deposit_id = req.dig("deposit", "id")
      return Caution.find_by(provider_request_id: deposit_id) if deposit_id.present?
      Caution.find_by(provider_request_id: req["id"])
    end

    def parse_time(value)
      Time.iso8601(value.to_s) rescue nil
    end
  end
end
