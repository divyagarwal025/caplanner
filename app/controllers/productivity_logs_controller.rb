class ProductivityLogsController < ApplicationController
  def index
    @logs = ProductivityLog.recent.limit(60)
  end

  def create
    log = ProductivityLog.capture(Date.current)
    log.assign_attributes(log_params)
    log.save
    redirect_to root_path, notice: "Tonight's productivity logged."
  end

  def update
    log = ProductivityLog.find_by!(date: Date.parse(params[:date]))
    log.update(log_params)
    redirect_to productivity_logs_path, notice: "Log updated."
  end

  private

  def log_params
    params.require(:productivity_log)
          .permit(:walked, :water_ok, :sleep_ok, :mood, :notes)
  end
end
