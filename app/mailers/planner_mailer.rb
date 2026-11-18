class PlannerMailer < ApplicationMailer
  # Sent in the morning: today's blocks + subject focus.
  def morning_brief(date = Date.current)
    @setting = Setting.instance
    @plan    = DayPlan.for(date)
    @date    = date
    @letter  = BriefWriter.new(today: date).morning_letter(@plan)

    mail to: @setting.email,
         subject: "☀️ Good Morning, #{BriefWriter::STUDENT_NAME}! Your CA plan for #{date.strftime('%a %d %b')}"
  end

  # Sent in the evening: how today went + a nudge to log it.
  def evening_review(date = Date.current)
    @setting = Setting.instance
    @plan    = DayPlan.find_by(date: date)
    @log     = ProductivityLog.capture(date)
    @streak  = ProductivityService.current_streak
    @date    = date
    @ai_intro = BriefWriter.new(today: date).evening(@plan&.completion_percent.to_i)

    mail to: @setting.email,
         subject: "🌙 #{date.strftime('%a %d %b')} — today's productivity review"
  end

  # Nightly: how today went + tomorrow's AI-adjusted plan and what to do next.
  def nightly_plan(date, tomorrow_plan)
    @setting   = Setting.instance
    @date      = date
    @plan      = DayPlan.find_by(date: date)
    @log       = ProductivityLog.capture(date)
    @streak    = ProductivityService.current_streak
    @road      = RoadmapService.new(today: date)
    @tomorrow  = tomorrow_plan
    @tasks     = tomorrow_plan&.task_items&.ordered || []
    @ai_intro  = BriefWriter.new(today: date).evening(@log&.completion_percent.to_i)
    @journey   = JourneyPlanner.new(today: date)
    @guide     = JourneyGuide.new(today: date).call
    @backlog   = BacklogService.owed_slots(before: date + 1)

    mail to: @setting.email,
         subject: "🌙 #{date.strftime('%a %d %b')} done — your plan for #{(date + 1).strftime('%a %d %b')}"
  end
end
