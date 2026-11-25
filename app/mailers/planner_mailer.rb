class PlannerMailer < ApplicationMailer
  # Sent in the morning: today's blocks + an AI-written motivational letter.
  # Records the send in daily_morning_mails (pending -> sent/failed).
  def morning_brief(date = Date.current)
    @user      = User.current
    @date      = date
    @milestone = Milestone.for_date(date)
    @item      = @milestone&.milestone_subject_task_items&.find_by(date: date)
    @letter    = BriefWriter.new(today: date, user: @user).morning_letter

    record = DailyMorningMail.for(@user, date)
    record.email_content = @letter.to_json
    record.status = "pending"
    record.save!

    mail to: @user.email,
         subject: "☀️ Good Morning, #{@user.display_name}! Your CA plan for #{date.strftime('%a %d %b')}"
  end

  # Fixed recipient for the nightly re-plan summary (per user request).
  NIGHT_REPLAN_TO = "agarwaldivy2508@gmail.com".freeze

  # Sent at night after the re-planner reflows upcoming days: a short summary of
  # what slipped and where it moved to.
  def nightly_replan(date, result)
    @user   = User.current
    @date   = date
    @result = result
    @moves  = Array(result.moves)

    status =
      if !result.ok? then "re-plan could not run"
      elsif result.changed? then "schedule refreshed"
      else "all on track"
      end

    mail to: NIGHT_REPLAN_TO,
         subject: "🌙 Plan update for #{(date + 1).strftime('%a %d %b')} — #{status}"
  end
end
