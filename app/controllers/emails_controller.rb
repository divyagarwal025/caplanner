class EmailsController < ApplicationController
  def morning
    PlannerMailer.morning_brief(Date.current).deliver_later
    redirect_to root_path, notice: "Morning brief queued — check preview / inbox."
  end

  def evening
    PlannerMailer.evening_review(Date.current).deliver_later
    redirect_to root_path, notice: "Evening review queued — check preview / inbox."
  end
end
