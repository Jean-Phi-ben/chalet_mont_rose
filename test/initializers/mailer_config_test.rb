require "test_helper"

class MailerConfigTest < ActiveSupport::TestCase
  def in_production
    original = Rails.env
    Rails.env = "production"
    yield
  ensure
    Rails.env = original
  end

  test "production refuses to boot without MAILER_FROM, except during the image build or in staging" do
    in_production do
      assert_raises(RuntimeError) { MailerConfig.check!({}) }
      assert_nothing_raised { MailerConfig.check!({ "MAILER_FROM" => "Chalet <contact@example.com>" }) }
      assert_nothing_raised { MailerConfig.check!({ "SECRET_KEY_BASE_DUMMY" => "1" }) }
      assert_nothing_raised { MailerConfig.check!({ "STAGING" => "true" }) }
    end
  end

  test "outside production nothing is required" do
    assert_nothing_raised { MailerConfig.check!({}) }
  end
end
