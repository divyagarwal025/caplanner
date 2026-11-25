# Productivity analytics — a single graph of daily completion, over a chosen
# range. A day's completion = share of its studyable blocks ticked done.
class AnalyticsController < ApplicationController
  RANGES = {
    "7"  => { days: 7,  label: "Last 7 days" },
    "14" => { days: 14, label: "Last 2 weeks" },
    "30" => { days: 30, label: "Last month" }
  }.freeze
  DEFAULT_RANGE = "7"

  def index
    @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
    days   = RANGES[@range][:days]

    @from = Date.current - (days - 1)
    @to   = Date.current

    items = MilestoneSubjectTaskItem
              .joins(:milestone)
              .where(milestones: { user_id: current_user.id }, date: @from..@to)
              .index_by(&:date)

    # Daily completion % for every day in the range (0 when there is no plan).
    @completion_series = (@from..@to).map do |d|
      [ d.strftime("%d %b"), items[d]&.completion_percent || 0 ]
    end
  end
end
