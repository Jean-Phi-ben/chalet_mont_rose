require "test_helper"

class Webhooks::SwiklyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 8, 1), check_out: Date.new(2026, 8, 8),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 150_000, deposit_cents: 45_000
    )
    CreateCautionJob.perform_now(@booking)
    @caution = @booking.reload.caution
  end

  # Helper : payload Swikly V2 (event + request avec deposit imbriqué).
  def secured_payload(deposit_status: "Accepted", accepted_at: Time.current.iso8601)
    {
      event: "requestSecured",
      request: {
        id: "req_xyz",
        deposit: {
          id: @caution.provider_request_id,
          status: deposit_status,
          acceptedAt: accepted_at
        }
      }
    }
  end

  test "requestSecured marks the caution as accepted" do
    post webhooks_swikly_url, params: secured_payload.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :success
    @caution.reload
    assert @caution.status_accepted?
    assert_not_nil @caution.accepted_at
  end

  test "allPendingRefundsCompleted releases the caution" do
    @caution.update!(status: :accepted, accepted_at: Time.current)
    payload = { event: "allPendingRefundsCompleted",
                request: { deposit: { id: @caution.provider_request_id } } }
    post webhooks_swikly_url, params: payload.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert @caution.reload.status_released?
    assert_not_nil @caution.released_at
  end

  test "allPendingReclaimsCompleted captures the caution" do
    @caution.update!(status: :accepted, accepted_at: Time.current)
    payload = { event: "allPendingReclaimsCompleted",
                request: { deposit: { id: @caution.provider_request_id } } }
    post webhooks_swikly_url, params: payload.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert @caution.reload.status_captured?
    assert_not_nil @caution.captured_at
  end

  test "malformed JSON is rejected" do
    post webhooks_swikly_url, params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
  end
end
