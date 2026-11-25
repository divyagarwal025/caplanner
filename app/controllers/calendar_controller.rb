# Month calendar. Every cell shows that day's blocks, read-only:
#   past days    -> whatever each block was left at (done / partial / not started)
#   today        -> same, the live states
#   future days  -> blocks are shown as not_started (nothing done yet)
# The calendar NEVER lets the user change a block's state — editing happens only
# on the full day page (day_plan_path). Cells are display-only.
class CalendarController < ApplicationController
  def index
    @month = build_month
    @first = @month.beginning_of_month
    @last  = @month.end_of_month
    @today = Date.current

    range = (@first.beginning_of_week(:sunday))..(@last.end_of_week(:sunday))

    # One day-item per date (across all milestones), keyed by date for O(1) cells.
    @items = MilestoneSubjectTaskItem
               .joins(:milestone)
               .where(milestones: { user_id: current_user.id }, date: range)
               .index_by(&:date)

    @weeks = range.to_a.each_slice(7).to_a
  end

  private

  def build_month
    if params[:year] && params[:month]
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    else
      Date.current.beginning_of_month
    end
  end
end
