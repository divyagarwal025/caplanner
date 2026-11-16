class AnalyticsController < ApplicationController
  def index
    logs = ProductivityLog.where(date: (Date.current - 29)..Date.current).order(:date)
    @completion_series = logs.map { |l| [ l.date.strftime("%d %b"), l.completion_percent ] }
  end
end
