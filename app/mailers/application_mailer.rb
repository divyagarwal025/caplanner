class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("PLANNER_FROM", "ca-planner@example.com")
  layout "mailer"
end
