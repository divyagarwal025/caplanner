class CalendarController < ApplicationController
  def index
    @month = build_month
    @first = @month.beginning_of_month
    @last  = @month.end_of_month

    # Pre-load plans and logs for the visible range to colour each cell.
    range  = (@first.beginning_of_week(:sunday))..(@last.end_of_week(:sunday))
    @plans = DayPlan.where(date: range).index_by(&:date)
    @logs  = ProductivityLog.where(date: range).index_by(&:date)
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
