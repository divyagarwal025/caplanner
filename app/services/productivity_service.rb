# Read-only study stats derived from the per-date plan items. A day's
# completion is the share of its studyable blocks ticked done.
module ProductivityService
  module_function

  # Completion percent for a single date (nil if there is no plan for it).
  def completion_for(date)
    item = item_for(date)
    item && item.completion_percent
  end

  # Consecutive days up to today whose completion was >= threshold.
  def current_streak(threshold: 70)
    streak = 0
    date = Date.current
    loop do
      pct = completion_for(date)
      break if pct.nil? || pct < threshold
      streak += 1
      date -= 1
    end
    streak
  end

  # Average completion over the last 7 days that actually have a plan.
  def week_completion_rate
    pcts = (0..6).map { |n| completion_for(Date.current - n) }.compact
    return 0 if pcts.empty?
    (pcts.sum / pcts.size.to_f).round
  end

  def item_for(date)
    milestone = Milestone.for_date(date)
    milestone&.milestone_subject_task_items&.find_by(date: date)
  end
end
