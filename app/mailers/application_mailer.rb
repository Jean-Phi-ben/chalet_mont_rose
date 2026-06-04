class ApplicationMailer < ActionMailer::Base
  helper ApplicationHelper
  helper MoneyHelper
  default from: "from@example.com"
  layout "mailer"
end
