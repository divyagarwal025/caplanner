class DayPlansController < ApplicationController
  def show
    @plan = DayPlan.for(Date.parse(params[:date]))
  end

  # Wipe and rebuild a day's blocks from the rotation (e.g. after changing kind).
  def regenerate
    plan = DayPlan.find(params[:id])
    plan.task_items.destroy_all
    DayPlanGenerator.new(plan.date).generate!
    redirect_to day_plan_path(plan.date.iso8601), notice: "Day regenerated."
  end
end
