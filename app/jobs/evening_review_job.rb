class EveningReviewJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    ProductivityLog.capture(date).save # snapshot block completion
    PlannerMailer.evening_review(date).deliver_now
  end
end
