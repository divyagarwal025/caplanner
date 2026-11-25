# A day's plan = the milestone_subject_task_item for that date. `show` renders
# the day's blocks (each with a 3-state status); `save` applies the chosen
# block statuses and rolls progress up to subject / revision-topic status.
class DayPlansController < ApplicationController
  def show
    @date      = Date.parse(params[:date])
    @milestone = Milestone.for_date(@date)
    @item      = day_item_for(@date)
  end

  # Persist each block's status, then roll up. Status is editable ONLY for today
  # and ONLY from the dashboard, so refuse any other date.
  def save
    @date = Date.parse(params[:date])

    unless @date == Date.current
      return redirect_to root_path, alert: "You can only update today's blocks."
    end

    item = day_item_for(@date)
    if item
      # params[:statuses] => { "0" => "done", "1" => "partially_done", ... }
      item.save_day!(params[:statuses]&.to_unsafe_h || {})
      notice = "Progress updated."
    else
      notice = "No plan found for today."
    end

    redirect_to root_path, notice: notice
  end

  # Placeholder until the deterministic day generator is wired as a service.
  def regenerate
    @date = Date.parse(params[:date])
    redirect_to day_plan_path(@date.iso8601), alert: "Regeneration not available yet."
  end
end
