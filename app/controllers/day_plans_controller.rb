# A day's plan = the milestone_subject_task_item for that date. `show` renders
# the day's blocks (each with a 3-state status); `save` applies the chosen
# block statuses and rolls progress up to subject / revision-topic status.
class DayPlansController < ApplicationController
  def show
    @date      = Date.parse(params[:date])
    @milestone = Milestone.for_date(@date)
    @item      = day_item_for(@date)
  end

  # Persist each block's status for the day, then roll up (the "Save" button).
  def save
    @date = Date.parse(params[:date])
    item  = day_item_for(@date)

    if item
      # params[:statuses] => { "0" => "done", "1" => "partially_done", ... }
      item.save_day!(params[:statuses]&.to_unsafe_h || {})
      notice = "Saved #{@date.strftime('%a %d %b')} — progress updated."
    else
      notice = "No plan found for #{@date.strftime('%a %d %b')}."
    end

    redirect_to day_plan_path(@date.iso8601), notice: notice
  end

  # Placeholder until the deterministic day generator is wired as a service.
  def regenerate
    @date = Date.parse(params[:date])
    redirect_to day_plan_path(@date.iso8601), alert: "Regeneration not available yet."
  end
end
