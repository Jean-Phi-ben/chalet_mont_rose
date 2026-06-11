ENV["RAILS_ENV"] ||= "test"

# Les tests doivent toujours tourner en mode stub des providers externes,
# indépendamment du .env de dev. On purge les clés avant de charger Rails
# pour que DropboxSignProvider.enabled? / SwiklyProvider.enabled? soient false.
%w[SWIKLY_API_KEY SWIKLY_API_SECRET SWIKLY_ACCOUNT_ID CAUTION_AMOUNT
   MAILER_OWNER_EMAIL BALANCE_REMINDER_DAYS].each { |k| ENV.delete(k) }

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
