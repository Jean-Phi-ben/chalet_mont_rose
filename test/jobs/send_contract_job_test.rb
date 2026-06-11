require "test_helper"

class SendContractJobTest < ActiveJob::TestCase
  setup do
    @booking = Booking.create!(
      check_in: Date.new(2026, 3, 7), check_out: Date.new(2026, 3, 14),
      first_name: "Léa", last_name: "Martin", email: "lea@example.com",
      phone: "+33600000000", total_price_cents: 150_000, deposit_cents: 45_000
    )
  end

  test "creates a Contract in :sent with frozen signer snapshot (no email sent — included in confirmation)" do
    assert_difference("Contract.count", 1) do
      assert_no_difference("ActionMailer::Base.deliveries.size") do
        SendContractJob.perform_now(@booking)
      end
    end
    contract = @booking.reload.contract
    assert contract.status_sent?
    assert_equal "Léa", contract.signer_first_name
    assert_equal "lea@example.com", contract.signer_email
    assert_equal "+33600000000", contract.signer_phone
    assert contract.token.present?
    assert_not_nil contract.sent_at
  end

  test "does not overwrite an already signed contract" do
    contract = Contract.create!(booking: @booking, status: :signed, signed_at: Time.current,
                                signed_ip: "1.2.3.4", document_hash: "h", signer_email: @booking.email)
    SendContractJob.perform_now(@booking)
    assert contract.reload.status_signed?
  end
end
