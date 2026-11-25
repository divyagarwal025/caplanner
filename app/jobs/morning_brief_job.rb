# Emails the day's morning brief to the single user. Scheduled at 7am daily
# (config/recurring.yml) and also triggerable from the dashboard button.
class MorningBriefJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    user = User.current
    PlannerMailer.morning_brief(date).deliver_now
    DailyMorningMail.for(user, date).update!(status: "sent")
  rescue => e
    Rails.logger.error("[MorningBriefJob] #{e.class}: #{e.message}")
    DailyMorningMail.for(User.current, date).update!(status: "failed") rescue nil
    raise
  end
end
