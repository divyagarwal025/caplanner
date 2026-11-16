# Runs each night. Snapshots today's completion, then reflows the roadmap:
# it carries over unfinished work, re-plans tomorrow with the AI (goal-driven,
# honouring the lectures -> revision 1 -> mocks+revision 2 phases toward the
# exam), and emails the user tomorrow's plan + what changed.
#
# This is the "auto-adjust on backlog" loop: if the user fell behind today, the
# plan for tomorrow (and the pace) shifts automatically to still finish before
# the exam, and the user is told exactly what to do next.
class NightlyReplanJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    # 1. Snapshot how today actually went.
    ProductivityLog.capture(date).save

    # 2. Reflow tomorrow toward the exam goal (AI when a key is set, else rules).
    result = NextDayPlanner.new(date + 1, today: date).call

    # 3. Email the user the evening review + tomorrow's adjusted plan.
    PlannerMailer.nightly_plan(date, result.plan).deliver_now
  end
end
