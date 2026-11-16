class DashboardController < ApplicationController
  def index
    @today      = DayPlan.for(Date.current)
    @subjects   = Subject.all
    @streak     = ProductivityService.current_streak
    @week_rate  = ProductivityService.week_completion_rate
    @tomorrow   = DayPlan.find_by(date: Date.current + 1)
    @ai_enabled = ENV["GROQ_API_KEY"].present?
    @road       = RoadmapService.new
    @night      = NightUpdate.for(Date.current)

    range = Date.current.beginning_of_week(:sunday)..Date.current.end_of_week(:sunday)
    @week_logs = ProductivityLog.where(date: range).index_by(&:date)
    @week_days = range.to_a
  end
end
