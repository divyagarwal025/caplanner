class MorningBriefJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    DayPlan.for(date) # ensure today's plan exists
    PlannerMailer.morning_brief(date).deliver_now
  end
end
