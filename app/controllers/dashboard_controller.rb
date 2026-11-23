class DashboardController < ApplicationController
  def index
    @date       = Date.current
    @milestone  = Milestone.for_date(@date)
    @today      = day_item_for(@date)
    @tomorrow   = day_item_for(@date + 1)
    @subjects   = current_user.subjects.ordered
    @milestones = current_user.milestones.chronological

    @streak     = ProductivityService.current_streak
    @week_rate  = ProductivityService.week_completion_rate
    @ai_enabled = AiClient.enabled?

    # Days remaining to the exam (= last milestone's end date).
    exam_end    = @milestones.last&.end_date
    @days_left  = exam_end ? [ (exam_end - @date).to_i, 0 ].max : nil

    # This calendar week's completion, by date, for the week strip.
    range       = @date.beginning_of_week(:sunday)..@date.end_of_week(:sunday)
    @week_days  = range.to_a
    @week_items = MilestoneSubjectTaskItem
                    .where(milestone: @milestones, date: range)
                    .index_by(&:date)
  end
end
