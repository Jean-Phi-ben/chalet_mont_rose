require "test_helper"

# Toutes les policies héritent du Scope d'ApplicationPolicy : un non-admin ne voit rien.
class PolicyScopeTest < ActiveSupport::TestCase
  POLICIES = {
    BookingPolicy => Booking, InvoicePolicy => Invoice, ClientPolicy => Client, DocumentPolicy => Document,
    EmailLogPolicy => EmailLog, WeeklyRatePolicy => WeeklyRate, BookingSettingPolicy => BookingSetting,
    TouristTaxPeriodPolicy => TouristTaxPeriod
  }.freeze

  test "non-admin users get an empty scope, admins the full one, for every policy" do
    admin  = User.new(email_address: "admin@example.com")
    client = User.new(email_address: "client@example.com")
    POLICIES.each do |policy, model|
      next unless model.respond_to?(:all) && model < ActiveRecord::Base

      assert_equal model.none.to_sql, policy::Scope.new(client, model).resolve.to_sql, "#{policy} : client"
      assert_equal model.all.to_sql,  policy::Scope.new(admin,  model).resolve.to_sql, "#{policy} : admin"
    end
  end
end
