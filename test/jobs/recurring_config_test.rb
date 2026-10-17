require "test_helper"

# Garde-fou : la tâche planifiée du rappel de solde doit rester déclarée pour
# la production et pointer vers une classe de job existante.
class RecurringConfigTest < ActiveSupport::TestCase
  test "production declares the daily balance reminder" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = config.fetch("production").fetch("balance_reminder")

    assert_equal BalanceReminderJob, task.fetch("class").constantize
    assert task.fetch("schedule").present?
  end
end
