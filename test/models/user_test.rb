require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "password must be at least PASSWORD_MIN_LENGTH characters" do
    user = User.new(email_address: "a@example.com", password: "a" * (User::PASSWORD_MIN_LENGTH - 1))
    assert_not user.valid?
    user.password = "a" * User::PASSWORD_MIN_LENGTH
    assert user.valid?
  end

  test "email verification token identifies the user and dies if the address changes" do
    user = User.create!(email_address: "a@example.com", password: "motdepasse")
    token = user.generate_token_for(:email_verification)
    assert_equal user, User.find_by_token_for(:email_verification, token)

    user.update!(email_address: "b@example.com")
    assert_nil User.find_by_token_for(:email_verification, token)
  end

  test "verify! sets email_verified_at once" do
    user = User.create!(email_address: "a@example.com", password: "motdepasse")
    assert_not user.verified?
    user.verify!
    first = user.email_verified_at
    assert user.verified?
    travel 1.hour do
      user.verify!
    end
    assert_equal first, user.reload.email_verified_at
  end
end
