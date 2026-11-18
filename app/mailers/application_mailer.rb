class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("PLANNER_FROM", "chhavigoyal030@gmail.com")
  layout "mailer"
end
