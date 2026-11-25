# Runs at night: reflows the active milestone's upcoming days based on how
# today actually went (NightlyReplanService), then emails a short summary of
# what moved to the fixed night-replan recipient. Scheduled daily at 10pm
# (config/recurring.yml).
class NightlyReplanJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    result = NightlyReplanService.new(date: date).run!
    PlannerMailer.nightly_replan(date, result).deliver_now
    result
  rescue => e
    Rails.logger.error("[NightlyReplanJob] #{e.class}: #{e.message}")
    raise
  end
end
