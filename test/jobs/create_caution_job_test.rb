require "test_helper"

class CreateCautionJobTest < ActiveJob::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      total_price_cents: 200_000, deposit_cents: 60_000
    )
  end

  test "creates a pending Caution with provider data (stub mode)" do
    CreateCautionJob.perform_now(@booking)
    caution = @booking.reload.caution
    assert_not_nil caution
    assert caution.status_pending?
    assert caution.provider_request_id.present?
    assert caution.deposit_url.present?
    assert caution.amount_cents.positive?
    assert_not_nil caution.requested_at
  end

  test "uses CAUTION_AMOUNT env when set, in euros converted to cents" do
    ENV["CAUTION_AMOUNT"] = "1500"
    CreateCautionJob.perform_now(@booking)
    assert_equal 150_000, @booking.reload.caution.amount_cents
  ensure
    ENV.delete("CAUTION_AMOUNT")
  end

  test "falls back to 30 percent of total clamped in 500-2000 €" do
    # 200_000 cts * 0.30 = 60_000 cts → dans la fourchette, donc 60_000.
    CreateCautionJob.perform_now(@booking)
    assert_equal 60_000, @booking.reload.caution.amount_cents
  end

  test "doesn't overwrite an accepted caution" do
    CreateCautionJob.perform_now(@booking)
    @booking.caution.update!(status: :accepted, accepted_at: Time.current)
    original_id = @booking.caution.provider_request_id

    CreateCautionJob.perform_now(@booking)
    assert @booking.reload.caution.status_accepted?
    assert_equal original_id, @booking.caution.provider_request_id
  end
end
