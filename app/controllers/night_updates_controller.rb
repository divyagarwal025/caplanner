class NightUpdatesController < ApplicationController
  # Save tonight's report (ticks are already saved via task toggles; here we
  # capture the free-text + block snapshot) and immediately plan tomorrow.
  def create
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    update = NightUpdate.for(date)
    update.assign_attributes(update_params)
    update.sync_from_plan!
    update.processed = false
    update.save!

    # AI reads the free-text report and ticks off what was actually finished,
    # so the planner (and goal progress) reflect real intent.
    NightUpdateInterpreter.new(update).call
    update.sync_from_plan! # refresh block counts after interpreter ticks
    update.save!

    result = NextDayPlanner.new(date + 1, today: date).call
    notice =
      if result.source == :ai
        "Got it. AI planned #{(date + 1).strftime('%a %d %b')}: #{result.plan.ai_summary}"
      else
        "Got it. Planned #{(date + 1).strftime('%a %d %b')} toward your exam goal" \
          "#{" (AI unavailable: #{result.error})" if result.error}."
      end

    redirect_to day_plan_path((date + 1).iso8601), notice: notice
  end

  private

  def update_params
    params.require(:night_update).permit(:raw_text)
  end
end
