class AddBalanceReminderSentAtToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :balance_reminder_sent_at, :datetime unless column_exists?(:invoices, :balance_reminder_sent_at)
  end
end
