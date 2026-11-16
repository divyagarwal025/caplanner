namespace :planner do
  desc "Send the morning brief for today"
  task morning: :environment do
    MorningBriefJob.perform_now(Date.current)
    puts "Morning brief sent to #{Setting.instance.email}."
  end

  desc "Send the evening productivity review for today"
  task evening: :environment do
    EveningReviewJob.perform_now(Date.current)
    puts "Evening review sent to #{Setting.instance.email}."
  end

  desc "Ensure today's plan exists (safe to run anytime)"
  task ensure_today: :environment do
    plan = DayPlan.for(Date.current)
    puts "Plan ready for #{plan.date} (#{plan.task_items.count} tasks)."
  end
end
